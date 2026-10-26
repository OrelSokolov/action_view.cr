# UrlHelper — byte-exact with actionview 8.1.4 (oracle: url_* cases).

module ActionView
  module Helpers
    module UrlHelper
      include TagHelper

      # link_to("Home", "/") -> <a href="/">Home</a>
      def link_to(text : String, url : String, **opts) : SafeString
        SafeString.new(%(<a#{link_attributes(url, opts)}>#{HTML.escape(text)}</a>))
      end

      # link_to "/x" do ... end — block content passes through raw
      # (compose markup with safe helpers inside the block).
      def link_to(url : String, **opts, &) : SafeString
        body = capture { yield }
        SafeString.new(%(<a#{link_attributes(url, opts)}>#{body}</a>))
      end

      private def link_attributes(url : String, opts) : String
        attrs = __av_opts_to_h(opts)
        attrs["href"] = url
        tag_options(attrs)
      end

      def link_to_if(condition : Bool, text : String, url : String, **opts, &) : String | SafeString
        condition ? link_to(text, url, **opts) : yield
      end

      def link_to_if(condition : Bool, text : String, url : String, **opts) : String | SafeString
        condition ? link_to(text, url, **opts) : ""
      end

      def link_to_unless(condition : Bool, text : String, url : String, **opts, &) : String | SafeString
        condition ? yield : link_to(text, url, **opts)
      end

      def link_to_unless(condition : Bool, text : String, url : String, **opts) : String | SafeString
        condition ? "" : link_to(text, url, **opts)
      end

      def mail_to(email : String, name : String? = nil, **opts) : SafeString
        attrs = __av_opts_to_h(opts)
        attrs["href"] = "mailto:#{email}"
        label = name || email
        SafeString.new(%(<a#{tag_options(attrs)}>#{HTML.escape(label)}</a>))
      end

      def button_to(name : String, url : String, **opts) : SafeString
        opts = __av_opts_to_h(opts)
        method = (opts.delete("method") || "post").to_s
        inner = String.build do |io|
          io << __av_method_field(method) unless method == "post"
          io << %(<input type="submit" value="#{HTML.escape(name)}"#{tag_options(opts)} />)
        end
        SafeString.new(%(<form class="button_to" method="post" action="#{HTML.escape(url)}">#{inner}</form>))
      end

      # button_to "/x" do ... end — html opts go to the submit <button>
      # (type="submit" appended after user opts, as in Rails); the form
      # tag keeps class → method → action insertion order (raw gem bytes
      # 8.1 AND 8.2 — the capybara parity harness sorts tag attributes
      # when saving artifacts, do not chase that order). method: get
      # switches the form method and drops the _method input.
      def button_to(url : String, *, method : String? = nil, **opts, &) : SafeString
        opts = __av_opts_to_h(opts)
        opts.delete("type")
        m = (method || "post").to_s
        form_method = m == "get" ? "get" : "post"
        body = capture { yield }
        SafeString.new(String.build do |io|
          io << %(<form class="button_to" method="#{form_method}" action="#{HTML.escape(url)}">)
          io << __av_method_field(m) unless m == "post" || m == "get"
          io << %(<button#{tag_options(opts)} type="submit">#{body}</button>)
          io << "</form>"
        end)
      end
    end
  end
end
