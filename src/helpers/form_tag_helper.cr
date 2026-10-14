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

      private def __av_sanitize_id(name : String) : String
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

      def check_box_tag(name : String, value : String = "1", checked : Bool = false, **opts) : SafeString
        SafeString.new(String.build do |io|
          io << %(<input type="checkbox" name="#{name}" id="#{__av_sanitize_id(name)}" value="#{value}")
          io << %( checked="checked") if checked
          io << tag_options(opts) << " />"
        end)
      end

      def radio_button_tag(name : String, value : String, checked : Bool = false, **opts) : SafeString
        SafeString.new(String.build do |io|
          io << %(<input type="radio" name="#{name}" id="#{__av_sanitize_id("#{name}_#{value}")}" value="#{value}")
          io << %( checked="checked") if checked
          io << tag_options(opts) << " />"
        end)
      end

      def text_area_tag(name : String, content : String? = nil, **opts) : SafeString
        SafeString.new(%(<textarea name="#{name}" id="#{__av_sanitize_id(name)}"#{tag_options(opts)}>#{content ? "\n#{HTML.escape(content)}" : ""}</textarea>))
      end

      def label_tag(name : String, text : String? = nil, **opts) : SafeString
        SafeString.new(%(<label for="#{__av_sanitize_id(name)}"#{tag_options(opts)}>#{HTML.escape(text || name.tr("_", " ").capitalize)}</label>))
      end

      def submit_tag(value : String = "Save changes", **opts) : SafeString
        SafeString.new(%(<input type="submit" name="commit" value="#{HTML.escape(value)}"#{tag_options(opts)} data-disable-with="#{HTML.escape(value)}" />))
      end

      def button_tag(content : String = "Button", **opts) : SafeString
        SafeString.new(%(<button name="button" type="submit"#{tag_options(opts)}>#{content}</button>))
      end

      # --- select ----------------------------------------------------
      def options_for_select(container : Array, selected : String | Int | Array(String) | Array(Int) | Nil = nil) : SafeString
        selected_list = selected.is_a?(Array) ? selected.map(&.to_s) : (selected ? [selected.to_s] : [] of String)
        SafeString.new(container.map { |item|
          label, value = item.is_a?(Tuple) || item.is_a?(Array) ? {item[0].to_s, item[1].to_s} : {item.to_s, item.to_s}
          sel = selected_list.includes?(value) ? %( selected="selected") : ""
          %(<option#{sel} value="#{HTML.escape(value)}">#{HTML.escape(label)}</option>)
        }.join("\n"))
      end

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
