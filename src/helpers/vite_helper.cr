# ViteHelper — порт vite_rails 3.0.19 lib/vite_rails/tag_helpers.rb
# поверх ViteRuby::Manifest (порт vite_ruby 3.9.2 lib/vite_ruby/
# manifest.rb). Оракулы: oracle/vite_cases.rb → oracle/vite_expected.yml
# (15 кейсов production-манифеста) и oracle/vite_dev_cases.rb →
# oracle/vite_dev_expected.yml (13 кейсов dev-режима) — сняты с
# настоящих гемов (те же версии, что пиннит qp2/website), зеркало —
# spec/vite_spec.cr.
#
# Wire-формат 1:1 (байты из оракулов):
# - <script src="..." crossorigin="anonymous" type="module"></script>
# - modulepreload: <link rel="modulepreload" href="..."
#   as="script" crossorigin="anonymous"> — БЕЗ самозакрывающего слэша
# - stylesheet: <link rel="stylesheet" href="..." /> (со слэшем),
#   у js-чанков — media="screen"
# - dev: entrypoint-теги указывают на /vite/entrypoints/... без чтения
#   манифеста, без modulepreload/stylesheet (граф резолвит браузер
#   через dev-сервер); vite_client_tag → /vite/@vite/client;
#   react-refresh — javascript_tag с CDATA-обёрткой (байты из
#   dev_react_refresh_tag)
# - несколько <script> склеиваются "\n", группы (scripts/preload/
#   stylesheets) — без разделителя
#
# Dev-режим (ViteRuby.dev_server_running?, порт
# ViteRuby#dev_server_running? из vite_ruby 3.9.2): TCP-проба
# host:port с кэшем на 1 секунду, включён только в development-режиме
# (mode из CRAILS_ENV/RAILS_ENV; тесты подменяют результат через
# ViteRuby.dev_server_running=). Проксирование HTTP/ws на dev-сервер —
# CRails::Middleware::ViteDevProxy в railties.cr.
#
# Задокументированные отклонения от гемов:
# - конфиг — class-свойства ViteRuby (path/manifest, entrypoints_dir,
#   public_output_dir, dev-режим) + env CRAILS_VITE_MANIFEST /
#   CRAILS_VITE_HOST / CRAILS_VITE_PORT; config/vite.json
#   не парсируется;
# - resolve_absolute_entry ("/...") режет ведущий слэш как ключ
#   манифеста (без relative_path_from-танцев гема и без /@fs/-
#   префикса dev-режима);
# - no auto_build: манифест не перестраивается по требованию;
# - кастомные options в теги не пробрасываются (только фиксированные
#   crossorigin:/type:/media:, как в дефолтных вызовах гема).

require "json"
require "socket"

module ViteRuby
  class MissingEntrypointError < Exception
    def initialize(file_name : String)
      super("Vite Ruby can't find #{file_name} in #{ViteRuby::Manifest.path}.\n" \
            "Possible causes:\n" \
            "  * vite build hasn't run (or the dev server isn't running)\n" \
            "  * the name is misspelled or missing an extension (type: :javascript|:stylesheet)")
    end
  end

  # --- dev-режим (порт ViteRuby#dev_server_running? / run_proxy?,
  # vite_ruby 3.9.2): mode из env, TCP-проба host:port с кэшем на 1
  # секунду (каждый lookup её вызывает). Тесты подменяют результат
  # через dev_server_running= (nil — авто-детект).
  class_property mode : String = ENV["CRAILS_ENV"]? || ENV["RAILS_ENV"]? ||
                                 ENV["RACK_ENV"]? || "development"
  class_property dev_server_host : String = ENV["CRAILS_VITE_HOST"]? || "127.0.0.1"
  class_property dev_server_port : Int32 = (ENV["CRAILS_VITE_PORT"]? || "5173").to_i
  class_property dev_server_connect_timeout : Float64 = 0.25

  @@dev_server_forced : Bool? = nil
  @@dev_server_running = false
  @@dev_server_checked_at : Time::Instant?

  def self.dev_server_running=(value : Bool?) : Nil
    @@dev_server_forced = value
  end

  # Прокси/дев-режим только в development (test — без CI, как в геме).
  def self.run_proxy? : Bool
    mode == "development" || (mode == "test" && !ENV["CI"]?)
  end

  def self.dev_server_running? : Bool
    forced = @@dev_server_forced
    return forced unless forced.nil?
    return false unless run_proxy?
    if (checked = @@dev_server_checked_at) &&
       (Time.instant - checked).total_seconds < 1
      return @@dev_server_running
    end
    @@dev_server_running = begin
      socket = TCPSocket.new(dev_server_host, dev_server_port,
        connect_timeout: dev_server_connect_timeout)
      socket.close
      true
    rescue Socket::Error | IO::Error
      false
    end
    @@dev_server_checked_at = Time.instant
    @@dev_server_running
  end

  # Порт ViteRuby::Manifest (production-режим, без auto_build).
  class Manifest
    # public/vite/.vite/manifest.json — дефолт vite build (vite 5/6).
    class_property path : String = ENV["CRAILS_VITE_MANIFEST"]? || "public/vite/.vite/manifest.json"
    class_property entrypoints_dir : String = "entrypoints"
    class_property public_output_dir : String = "vite"

    @@instance : Manifest?

    def self.instance : Manifest
      @@instance ||= new
    end

    # Тесты/консоль подменяют путь и сбрасывают кэш.
    def self.reset : Nil
      @@instance = nil
    end

    struct Entry
      attr_reader file : String       # уже с префиксом /vite/
      attr_reader css : Array(String)
      attr_reader imports : Array(Entry)

      def initialize(@file, @css, @imports)
      end
    end

    attr_reader entries : Hash(String, Entry)

    def initialize
      raw = {} of String => JSON::Any
      if File.exists?(Manifest.path)
        JSON.parse(File.read(Manifest.path)).as_h.each do |k, v|
          raw[k] = v
        end
      end
      @entries = resolve_references(raw)
    end

    # path_for("application", type: :javascript) → "/vite/assets/x-hash.js"
    def path_for(name : String, type : String? = nil) : String
      lookup!(name, type).file
    end

    # resolve_entries: scripts / modulepreload-импорты / css-чанки.
    # В dev импортов и стилей нет — их резолвит браузер через
    # dev-сервер (find_manifest_entry/react-preamble из гема).
    def resolve_entries(names : Array(String)) : NamedTuple(scripts: Array(String), imports: Array(String), stylesheets: Array(String))
      if ViteRuby.dev_server_running?
        scripts = names.map { |name| lookup!(name, "javascript").file }
        return {scripts: scripts, imports: [] of String, stylesheets: [] of String}
      end
      entries = names.map { |name| lookup!(name, "javascript") }
      scripts = entries.map(&.file)
      import_entries = entries.flat_map(&.imports)
      imports = import_entries.map(&.file).uniq
      stylesheets = (entries + import_entries).flat_map(&.css).uniq
      {scripts: scripts, imports: imports, stylesheets: stylesheets}
    end

    def lookup!(name : String, type : String? = nil) : Entry
      lookup(name, type) || raise MissingEntrypointError.new(
        resolve_entry_name(name, type))
    end

    def lookup(name : String, type : String? = nil) : Entry?
      key = resolve_entry_name(name, type)
      # dev: файл резолвится без манифеста — /vite/<имя> отдаёт
      # dev-сервер (find_manifest_entry гема).
      return Entry.new(prefix(key), [] of String, [] of Entry) if ViteRuby.dev_server_running?
      @entries[key]?
    end

    # Путь HMR-клиента (vite_client_src гема): prefix_asset_with_host =
    # File.join("/", public_output_dir, "@vite/client") — с того же
    # origin, через прокси (skip_proxy не поддержан).
    def vite_client_src : String?
      return unless ViteRuby.dev_server_running?
      File.join("/", Manifest.public_output_dir, "@vite/client")
    end

    # React Refresh preamble (react_preamble_code гема, байты из
    # оракула dev_react_preamble_code).
    def react_preamble_code : String?
      return unless ViteRuby.dev_server_running?
      refresh = File.join("/", Manifest.public_output_dir, "@react-refresh")
      {
        "import RefreshRuntime from '#{refresh}'",
        "RefreshRuntime.injectIntoGlobalHook(window)",
        "window.$RefreshReg$ = () => {}",
        "window.$RefreshSig$ = () => (type) => type",
        "window.__vite_plugin_react_preamble_installed__ = true",
      }.join('\n') + '\n'
    end

    # resolve_entry_name используется и для текста ошибки отсутствия.
    def resolve_entry_name(name : String, type : String?) : String
      name = with_file_extension(name, type)
      if name.starts_with?('.')
        raise ArgumentError.new("Asset names can not be relative. Found: #{name}")
      end
      # ~/ — относительно sourceCodeDir (app/frontend)
      return name[2..] if name.starts_with?("~/")
      # / — относительно корня проекта
      return name[1..] if name.starts_with?('/')
      # сахар: без вложенности — префикс entrypoints/
      name.includes?('/') ? name : File.join(Manifest.entrypoints_dir, name)
    end

    private def with_file_extension(name : String, type : String?) : String
      return name unless File.extname(name).empty?
      case type
      when "javascript" then "#{name}.js"
      when "stylesheet" then "#{name}.css"
      when "typescript" then "#{name}.ts"
      else                   name
      end
    end

    # resolve_references: префиксуем file/css через public_output_dir,
    # imports разворачиваем в готовые Entry (граф ссылок манифеста).
    private def resolve_references(raw : Hash(String, JSON::Any)) : Hash(String, Entry)
      files = {} of String => NamedTuple(file: String, css: Array(String), imports: Array(String))
      raw.each do |key, value|
        fields = value.as_h?
        next unless fields
        file = fields["file"]?.try(&.as_s)
        next unless file
        css = fields["css"]?.try { |v| v.as_a.map(&.as_s) } || [] of String
        imports = fields["imports"]?.try { |v| v.as_a.map(&.as_s) } || [] of String
        files[key] = {file: prefix(file), css: css.map { |c| prefix(c) }, imports: imports}
      end
      final = {} of String => Entry
      files.each do |key, f|
        deps = f[:imports].map do |name|
          if d = files[name]?
            Entry.new(d[:file], d[:css], [] of Entry)
          else
            Entry.new(prefix(name), [] of String, [] of Entry)
          end
        end
        final[key] = Entry.new(f[:file], f[:css], deps)
      end
      final
    end

    private def prefix(path : String) : String
      File.join("/", Manifest.public_output_dir, path)
    end
  end

  # Небольшой сахар для `raise` из lookup!.
  def self.manifest : Manifest
    Manifest.instance
  end
end

module ActionView
  module Helpers
    module ViteHelper
      # vite_asset_path "application" (type: :javascript|:stylesheet)
      def vite_asset_path(name : String, type : String? = nil) : String
        ViteRuby.manifest.path_for(name, type)
      end

      def vite_asset_url(name : String, type : String? = nil) : String
        vite_asset_path(name, type)
      end

      # vite_javascript_tag "application", "second" — script-теги (ESM),
      # modulepreload для чанков-импортов и stylesheet для css-чанков.
      def vite_javascript_tag(*names : String, type : String = "module",
                              skip_preload_tags : Bool = false,
                              skip_style_tags : Bool = false,
                              crossorigin : String = "anonymous",
                              media : String = "screen") : SafeString
        entries = ViteRuby.manifest.resolve_entries(names.to_a)
        tags = entries[:scripts].map { |src|
          %(<script src="#{src}" crossorigin="#{crossorigin}" type="#{type}"></script>)
        }.join("\n")
        unless skip_preload_tags || entries[:imports].empty?
          preload = entries[:imports].map { |href|
            %(<link rel="modulepreload" href="#{href}" as="script" crossorigin="#{crossorigin}">)
          }.join("\n")
          tags += preload
        end
        unless skip_style_tags || entries[:stylesheets].empty?
          tags += entries[:stylesheets].map { |href|
            %(<link rel="stylesheet" href="#{href}" media="#{media}" />)
          }.join
        end
        SafeString.new(tags)
      end

      def vite_typescript_tag(*names : String) : SafeString
        # asset_type: :typescript — расширение .ts при lookup
        entries = names.to_a
        tags = entries.map { |name|
          src = ViteRuby.manifest.path_for(name, "typescript")
          %(<script src="#{src}" crossorigin="anonymous" type="module"></script>)
        }.join("\n")
        SafeString.new(tags)
      end

      def vite_stylesheet_tag(*names : String, **opts) : SafeString
        links = names.map { |name|
          %(<link rel="stylesheet" href="#{vite_asset_path(name, "stylesheet")}"#{tag_options(opts)} />)
        }.join("\n")
        SafeString.new(links)
      end

      def vite_image_tag(name : String, **opts) : SafeString
        opts = __av_opts_to_h(opts)
        opts["src"] = vite_asset_path(name)
        SafeString.new(%(<img#{tag_options(opts)} />))
      end

      # HMR-клиент: '<script src="/vite/@vite/client" ...>' — только с
      # dev-сервером (оракул dev_client_tag, байты javascript_include_tag:
      # src/crossorigin/type).
      def vite_client_tag(crossorigin : String = "anonymous") : SafeString?
        src = ViteRuby.manifest.vite_client_src
        return nil unless src
        SafeString.new(%(<script src="#{src}" crossorigin="#{crossorigin}" type="module"></script>))
      end

      # React Refresh (оракул dev_react_refresh_tag): javascript_tag с
      # CDATA-обёрткой; nonce: true гема — без CSP-контроллера даёт
      # nil, атрибут не ставится.
      def vite_react_refresh_tag : SafeString?
        code = ViteRuby.manifest.react_preamble_code
        return nil unless code
        SafeString.new("<script type=\"module\">\n//<![CDATA[\n#{code}\n//]]>\n</script>")
      end
    end
  end
end
