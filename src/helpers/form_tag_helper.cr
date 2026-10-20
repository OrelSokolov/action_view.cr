# FormTagHelper — byte-exact with actionview 8.1.4 (oracle: ft_*
# cases). The CSRF token hidden field is emitted through
# `__csrf_token_field`, overridden by ActionController::Base when
# protect_from_forgery is on (RequestForgeryProtection); in plain view
# contexts it stays "" — same output as before, byte-exact with the
# oracle harness (which runs with protect_against_forgery? false).

module ActionView
  module Helpers
    module FormTagHelper
      include TagHelper
      include FormOptionsHelper

      # No forgery layer in plain view contexts; overridden by
      # RequestForgeryProtection in controllers.
      protected def __protect_against_forgery? : Bool
        false
      end

      # CSRF token hidden input for non-GET forms (""); overridden by
      # RequestForgeryProtection.
      protected def __csrf_token_field(action : String, method : String) : String
        ""
      end

      UTF8_ENROLLMENT = %(<input type="hidden" name="utf8" value="&#x2713;" autocomplete="off" />)

      def __av_sanitize_id(name : String) : String
        name.delete(']').chars.map { |c|
          c.alphanumeric? || "-.:".includes?(c) ? c : "_"
        }.join
      end

      private def __av_field(type : String, name : String, value : String?, **opts) : SafeString
        SafeString.new(String.build do |io|
          io << %(<input type="#{type}" name="#{name}" id="#{__av_sanitize_id(name)}")
          io << %( value="#{HTML.escape(value)}") if value
          io << tag_options(opts) << " />"
        end)
      end

      def text_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("text", name, value, **opts)
      end

      def password_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("password", name, value, **opts)
      end

      def email_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("email", name, value, **opts)
      end

      def search_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("search", name, value, **opts)
      end

      def url_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("url", name, value, **opts)
      end

      def telephone_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("tel", name, value, **opts)
      end

      def date_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("date", name, value, **opts)
      end

      def time_field_tag(name : String, value : String | Time | Nil = nil, **opts) : SafeString
        __av_field("time", name, value.try(&.to_s), **opts)
      end

      # Rails 8.1: both datetime flavors render type="datetime-local"
      # (the HTML "datetime" input type was dropped).
      def datetime_field_tag(name : String, value : String | Time | Nil = nil, **opts) : SafeString
        __av_field("datetime-local", name, value.try(&.to_s), **opts)
      end

      def datetime_local_field_tag(name : String, value : String | Time | Nil = nil, **opts) : SafeString
        __av_field("datetime-local", name, value.try(&.to_s), **opts)
      end

      def month_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("month", name, value, **opts)
      end

      def week_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("week", name, value, **opts)
      end

      def phone_field_tag(name : String, value : String? = nil, **opts) : SafeString
        telephone_field_tag(name, value, **opts)
      end

      def file_field_tag(name : String, **opts) : SafeString
        __av_field("file", name, nil, **opts)
      end

      def color_field_tag(name : String, value : String? = nil, **opts) : SafeString
        __av_field("color", name, value, **opts)
      end

      def number_field_tag(name : String, value : String | Int | Float | Nil = nil, **opts) : SafeString
        __av_field("number", name, value.try(&.to_s), **opts)
      end

      def range_field_tag(name : String, value : String | Int | Float | Nil = nil, **opts) : SafeString
        __av_field("range", name, value.try(&.to_s), **opts)
      end

      def hidden_field_tag(name : String, value : String? = nil, **opts) : SafeString
        SafeString.new(String.build do |io|
          io << %(<input type="hidden" name="#{name}" id="#{__av_sanitize_id(name)}")
          io << %( value="#{HTML.escape(value)}") if value
          io << %( autocomplete="off")
          io << tag_options(opts) << " />"
        end)
      end

      # Rails builds these as a base hash {type, name, id, value} updated
      # in place with the options hash (existing keys keep their slot,
      # new keys append) and `checked` appended last — the oracle locks
      # that attribute order (opts land before `checked`, `id: nil`
      # drops the id, explicit `id:` replaces it in place).
      def check_box_tag(name : String, value : String = "1", checked : Bool = false, **opts) : SafeString
        h = {"type" => "checkbox", "name" => name, "id" => __av_sanitize_id(name), "value" => value} of String => AttrVal
        __av_opts_to_h(opts).each { |k, v| h[k] = v }
        h["checked"] = "checked" if checked
        SafeString.new(%(<input#{tag_options(h)} />))
      end

      def radio_button_tag(name : String, value : String, checked : Bool = false, **opts) : SafeString
        h = {"type" => "radio", "name" => name, "id" => __av_sanitize_id("#{name}_#{value}"), "value" => value} of String => AttrVal
        __av_opts_to_h(opts).each { |k, v| h[k] = v }
        h["checked"] = "checked" if checked
        SafeString.new(%(<input#{tag_options(h)} />))
      end

      def text_area_tag(name : String, content : String? = nil, **opts) : SafeString
        SafeString.new(%(<textarea name="#{name}" id="#{__av_sanitize_id(name)}"#{tag_options(opts)}>#{content ? "\n#{HTML.escape(content)}" : ""}</textarea>))
      end

      # Oracle: user opts render BEFORE the generated `for` attribute.
      def label_tag(name : String, text : String? = nil, **opts) : SafeString
        SafeString.new(%(<label#{tag_options(opts)} for="#{__av_sanitize_id(name)}">#{HTML.escape(text || name.tr("_", " ").capitalize)}</label>))
      end

      def label_tag(name : String, **opts, &) : SafeString
        body = capture { yield }
        SafeString.new(%(<label#{tag_options(opts)} for="#{__av_sanitize_id(name)}">#{body}</label>))
      end

      def submit_tag(value : String = "Save changes", **opts) : SafeString
        SafeString.new(%(<input type="submit" name="commit" value="#{HTML.escape(value)}"#{tag_options(opts)} data-disable-with="#{HTML.escape(value)}" />))
      end

      # Base defaults {name, type} merge with opts (explicit name/type
      # replace the defaults in place); with a block the content comes
      # from capture, as in Rails.
      def button_tag(content : String = "Button", **opts) : SafeString
        h = {"name" => "button", "type" => "submit"} of String => AttrVal
        __av_opts_to_h(opts).each { |k, v| h[k] = v }
        SafeString.new(%(<button#{tag_options(h)}>#{HTML.escape(content)}</button>))
      end

      def button_tag(**opts, &) : SafeString
        h = {"name" => "button", "type" => "submit"} of String => AttrVal
        __av_opts_to_h(opts).each { |k, v| h[k] = v }
        body = capture { yield }
        SafeString.new(%(<button#{tag_options(h)}>#{body}</button>))
      end

      # Oracle: src goes through the image-asset path ("/images/"
      # prefix unless absolute or a full URL); no name/alt defaults in
      # actionview 8.1.
      def image_submit_tag(source : String, **opts) : SafeString
        src = source.starts_with?('/') || source.includes?("://") ? source : "/images/#{source}"
        h = {"type" => "image", "src" => src} of String => AttrVal
        __av_opts_to_h(opts).each { |k, v| h[k] = v }
        SafeString.new(%(<input#{tag_options(h)} />))
      end

      # --- select ----------------------------------------------------
      # options_for_select lives in FormOptionsHelper (as in Rails),
      # brought in through the include chain.
      def select_tag(name : String, option_tags : String | SafeString | Nil = nil, **opts) : SafeString
        opts = __av_opts_to_h(opts)
        html_name = opts["multiple"]? ? "#{name}[]" : name
        prompt_opt = opts.delete("prompt")
        prompt = prompt_opt.nil? ? nil : prompt_opt.to_s
        options = String.build do |io|
          io << %(<option value="">#{HTML.escape(prompt)}</option>) if prompt && !prompt.empty?
          io << option_tags.to_s
        end
        id_opt = opts.delete("id")
        id = id_opt.nil? ? __av_sanitize_id(name) : id_opt.to_s
        SafeString.new(%(<select name="#{html_name}" id="#{id}"#{tag_options(opts)}>#{options}</select>))
      end

      # --- form ------------------------------------------------------
      # form_tag "/posts" do ... end — the helper appends the open tags
      # to the output buffer, the block writes the fields, then the
      # closing tag. Returns "" so the compiled `<%= %>` adds nothing.
      def form_tag(url : String? = nil, **opts, &) : String
        opts = __av_opts_to_h(opts)
        method = (opts.delete("method") || "post").to_s
        # Rails: authenticity_token: false drops the utf8 enrollment
        # hidden field and the CSRF token.
        skip_enrollment = opts.delete("authenticity_token").== false
        __erb_out(String.build do |io|
          io << %(<form action="#{HTML.escape(url.to_s)}" accept-charset="UTF-8"#{tag_options(opts)} method="post">)
          io << UTF8_ENROLLMENT unless skip_enrollment
          io << %(<input type="hidden" name="_method" value="#{method}" autocomplete="off" />) unless method == "post"
          io << __csrf_token_field(url.to_s, method) unless skip_enrollment || method == "get"
        end)
        yield
        __erb_out "</form>"
        ""
      end
    end
  end
end
