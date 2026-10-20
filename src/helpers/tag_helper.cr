# TagHelper: tag()/content_tag()/tag.<name> — byte-exact with
# actionview 8.1.4 (oracle: tag_*, ct_* cases).
#
# Quirk preserved from Rails: `tag("br")` emits `<br />`, while the
# dot form `tag.br` emits `<br>` (TagBuilder#tag_string).

module ActionView
  module Helpers
    module TagHelper
      # The _method hidden input (used by form_with/form_tag/button_to);
      # autocomplete gated by config (8.1 gem emits it, edge/8.2 does
      # not — oracle fw_local_method).
      def __av_method_field(method : String) : String
        ac = FormTagHelper.method_field_autocomplete ? %( autocomplete="off") : ""
        %(<input type="hidden" name="_method" value="#{method}"#{ac} />)
      end

      # Escapes attribute values the way Rails tag_options does.
      def self.__av_attr_escape(value : String) : String
        value.gsub('&', "&amp;")
          .gsub('"', "&quot;")
          .gsub('<', "&lt;")
          .gsub('>', "&gt;")
      end

      def __av_attr_escape(value : String) : String
        TagHelper.__av_attr_escape(value)
      end

      def self.__av_value_to_s(value) : String
        value.to_s
      end

      def __av_value_to_s(value) : String
        value.to_s
      end

      # Renders `key="value"` pairs: boolean attributes as `key="key"` /
      # omitted (BOOLEAN_ATTRIBUTES), other Bool values as "true"/"false",
      # nil omitted, nested `data:`/`aria:` hashes flattened. Accepts
      # both Hash and NamedTuple (what `**opts` double splats to).
      # Normalizes `**opts` double splats (NamedTuple, possibly empty)
      # into String-keyed hashes; nested NamedTuples (data: {controller: "x"})
      # become String-keyed Hashes the same way.
      alias AttrVal = String | Int32 | Int64 | Float64 | Bool | Nil | Hash(String, AttrVal)

      def __av_opts_to_h(opts) : Hash(String, AttrVal)
        h = {} of String => AttrVal
        opts.each do |k, v|
          h[k.to_s] = __av_normalize_val(v)
        end
        h
      end

      # Symbol → String, nested NamedTuple/Hash (data: {controller: "x"},
      # possibly symbol-keyed) → String-keyed Hash; AttrVal passes through.
      def self.__av_normalize_val(v) : AttrVal
        case v
        when Symbol     then v.to_s
        when NamedTuple, Hash
          nested = {} of String => AttrVal
          v.each { |nk, nv| nested[nk.to_s] = TagHelper.__av_normalize_val(nv) }
          nested
        else v.as(AttrVal)
        end
      end

      def __av_normalize_val(v) : AttrVal
        TagHelper.__av_normalize_val(v)
      end

      def tag_options(opts) : String
        String.build do |io|
          opts.each do |key, value|
            __av_tag_option(io, key.to_s, __av_normalize_val(value))
          end
        end
      end

      # Static entry point for code outside a view (turbo.cr's tag
      # builders run on channel/model classes, not view instances).
      def self.tag_options(opts) : String
        String.build do |io|
          opts.each do |key, value|
            new_tag_option(io, key.to_s, TagHelper.__av_normalize_val(value))
          end
        end
      end

      private def __av_tag_option(io : IO, key : String, value) : Nil
        TagHelper.new_tag_option(io, key, value)
      end

      # Rails BOOLEAN_ATTRIBUTES (actionview 8.1.4): these keys render
      # `key="key"` when true and are omitted when false; every OTHER
      # key with a Bool value goes through tag_option's to_s — "true"/
      # "false" (oracle tag_data_bool: data: {x: true} → data-x="true").
      BOOLEAN_ATTRIBUTES = %w(allowfullscreen allowpaymentrequest async autofocus
                              autoplay checked compact controls declare default
                              defaultchecked defaultmuted defaultselected defer
                              disabled enabled formnovalidate hidden indeterminate
                              inert ismap itemscope loop multiple muted nohref
                              nomodule noresize noshade novalidate nowrap open
                              pauseonexit playsinline readonly required reversed
                              scoped seamless selected sortable truespeed
                              typemustmatch visible)

      def self.new_tag_option(io : IO, key : String, value) : Nil
        case value
        when Bool
          if BOOLEAN_ATTRIBUTES.includes?(key)
            io << " " << key << %(="#{key}") if value
          else
            io << " " << key << %(="#{value}")
          end
        when Nil
          # omitted
        when Hash
          value.each do |nested_key, nested_value|
            new_tag_option(io, "#{key}-#{nested_key.to_s.gsub('_', '-')}", nested_value)
          end
        else
          io << " " << key << "=" << '"' << __av_attr_escape(__av_value_to_s(value)) << '"'
        end
      end

      # `tag("br")` -> `<br />`; `tag("img", src: ...)` -> `<img src="..." />`
      def tag(name : String | Symbol, **attrs) : SafeString
        SafeString.new("<#{name}#{tag_options(attrs)} />")
      end

      # Dot form: `tag.br` -> `<br>` (no closing slash, as in Rails).
      def tag : TagBuilder
        TagBuilder.new(self)
      end

      def content_tag(name : String | Symbol, content : String? = nil, **attrs) : SafeString
        inner = content ? HTML.escape(content) : ""
        SafeString.new("<#{name}#{tag_options(attrs)}>#{inner}</#{name}>")
      end

      def content_tag(name : String | Symbol, **attrs, &) : SafeString
        body = capture { yield }
        SafeString.new("<#{name}#{tag_options(attrs)}>#{body}</#{name}>")
      end

      # `tag.div class: "x" { ... }` / `tag.br`
      class TagBuilder
        def initialize(@view : ActionView::Helpers)
        end

        macro method_missing(call)
          {% extra = "" %}
          {% unless call.named_args.is_a?(Nop) %}
            {% extra = "**{ " + call.named_args.map { |na| "#{na.name.id}: #{na.value}" }.join(", ") + " }" %}
          {% end %}
          {% if call.block %}
            @view.content_tag({{ call.name.stringify }}, {{ extra.id }}) {{ call.block }}
          {% else %}
            __av_tag_string({{ call.name.stringify }}, {{ extra.id }})
          {% end %}
        end

        def __av_tag_string(name : String, **attrs) : String
          "<#{name}#{@view.tag_options(attrs)}>"
        end
      end
    end
  end
end
