# EmbedFileHelper — CRails-расширение (не из actionview): инлайн
# SVG-ассетов в разметку. Замена хардкоду SVG в контроллерах/вьюхах —
# иконки лежат файлами в app/assets/* и резолвятся по logical path
# той же семантикой, что Static-мидлварь railties для /assets/*
# (propshaft load path: каждый подкаталог assets root добавляет свои
# файлы по пути относительно себя).

module ActionView
  module Helpers
    module EmbedFileHelper
      include TagHelper

      # Assets root (относительно cwd процесса). Переопределяется в
      # тестах/кастомной структурой каталогов.
      class_property assets_root : String = "app/assets"

      # Кэш прочитанных файлов: пути стабильны, содержимое immutable.
      @@content_cache : Hash(String, String) = {} of String => String

      # Инлайнит файл ассета (обычно SVG) как trusted HTML.
      #
      #   embed_file("icons/payment/tether.svg")
      #   embed_file("icons/payment/tether.svg", class: "w-8 h-8", data: {"test" => "icon"})
      #
      # Опции (если заданы) мержатся в атрибуты корневого <svg>-тега,
      # перекрывая одноимённые (семантика inline_svg). Файлы без
      # корневого <svg> возвращаются как есть. Прочитанный файл
      # кэшируется на процесс.
      def embed_file(source : String, **opts) : SafeString
        content = embed_read(source)
        return SafeString.new(content) if opts.empty?
        SafeString.new(embed_inject_attrs(content, __av_opts_to_h(opts)))
      end

      # Прочитывает и кэширует файл ассета по logical path.
      def embed_read(source : String) : String
        unless path = embed_resolve(source)
          raise ArgumentError.new(
            "embed_file: asset not found: #{source} (searched #{EmbedFileHelper.assets_root}/*)")
        end
        @@content_cache[path] ||= File.read(path)
      end

      # Propshaft-резолвинг: logical path ищется в подкаталогах
      # assets root (app/assets/icons/x.svg → "icons/x.svg" найден в
      # любом подкаталоге). Nil, если не найден.
      def embed_resolve(source : String) : String?
        return source if File.file?(source)
        return nil unless Dir.exists?(EmbedFileHelper.assets_root)
        Dir.glob(File.join(EmbedFileHelper.assets_root, "*")).sort.each do |dir|
          next unless File.directory?(dir)
          candidate = File.join(dir, source)
          return candidate if File.file?(candidate)
        end
        nil
      end

      private def embed_inject_attrs(content : String, attrs : Hash(String, AttrVal)) : String
        svg_start = content.index("<svg")
        return content unless svg_start
        tag_end = content.index('>', svg_start)
        return content unless tag_end
        open_tag = content[svg_start..tag_end]

        # Существующие атрибуты корневого тега; одноимённые опции их
        # перекрывают.
        merged = {} of String => AttrVal
        open_tag.scan(/[\w:-]+\s*=\s*"[^"]*"/) do |match|
          key, _, value = match[0].partition(/\s*=\s*/)
          merged[key] = value[1..-2]
        end
        attrs.each { |k, v| merged[k] = v }

        head = svg_start > 0 ? content[0...svg_start] : ""
        "#{head}<svg#{tag_options(merged)}>#{content[(tag_end + 1)..]}"
      end
    end
  end
end
