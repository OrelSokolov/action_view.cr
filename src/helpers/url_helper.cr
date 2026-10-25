# UrlHelper — byte-exact with actionview 8.1.4 (oracle: url_* cases).

module ActionView
  module Helpers
    module UrlHelper
      include TagHelper

      # Rails 8.1 button_to (url_button_* oracle cases): form tag
      # class → method → action, method field through __av_method_field
      # (type → name → value, autocomplete per method_field_autocomplete,
      # self-closing). edge/8.2 rewrote button_to: form attributes
      # action → class → method and a plain
      # <input name="_method" type="hidden" value="..."> (name first, no
      # autocomplete, no self-closing slash). Apps on rails 8.2 set
      # this to true (byte-parity with the app oracle's button_to forms).
      class_property button_to_edge_82 = false

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
          io << __button_to_method_field(method) unless method == "post"
          io << %(<input type="submit" value="#{HTML.escape(name)}"#{tag_options(opts)} />)
        end
        SafeString.new(%(#{__button_to_form_open(url)}#{inner}</form>))
      end

      # button_to "/x" do ... end — html opts go to the submit <button>
      # (type="submit" appended after user opts, as in Rails); the form
      # tag keeps the button_to attribute order (8.1: class → method →
      # action; edge/8.2: action → class → method). method: get
      # switches the form method and drops the _method input.
      def button_to(url : String, *, method : String? = nil, **opts, &) : SafeString
        opts = __av_opts_to_h(opts)
        opts.delete("type")
        # edge/8.2 emits the submit <button> attributes in sorted key
        # order (oracle artifacts: aria-checked → aria-labelledby →
        # class → role → tabindex → type); nested data/aria hashes sort
        # recursively.
        opts = __av_sorted_opts(opts) if UrlHelper.button_to_edge_82
        m = (method || "post").to_s
        form_method = m == "get" ? "get" : "post"
        body = capture { yield }
        SafeString.new(String.build do |io|
          io << __button_to_form_open(url, form_method)
          io << __button_to_method_field(m) unless m == "post" || m == "get"
          io << %(<button#{tag_options(opts)} type="submit">#{body}</button>)
          io << "</form>"
        end)
      end

      private def __av_sorted_opts(opts : Hash(String, TagHelper::AttrVal)) : Hash(String, TagHelper::AttrVal)
        sorted = {} of String => TagHelper::AttrVal
        opts.keys.sort.each do |k|
          v = opts[k]
          sorted[k] = v.is_a?(Hash) ? __av_sorted_opts(v.as(Hash(String, TagHelper::AttrVal))) : v
        end
        sorted
      end

      private def __button_to_form_open(url : String, form_method : String = "post") : String
        if UrlHelper.button_to_edge_82
          %(<form action="#{HTML.escape(url)}" class="button_to" method="#{form_method}">)
        else
          %(<form class="button_to" method="#{form_method}" action="#{HTML.escape(url)}">)
        end
      end

      private def __button_to_method_field(method : String) : String
        if UrlHelper.button_to_edge_82
          %(<input name="_method" type="hidden" value="#{method}">)
        else
          __av_method_field(method)
        end
      end
    end
  end
end
