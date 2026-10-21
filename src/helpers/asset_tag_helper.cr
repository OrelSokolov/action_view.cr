# AssetTagHelper — byte-exact with actionview 8.1.4 (oracle: asset_*
# cases). Fingerprints/manifests come later (P1): plain
# /stylesheets|javascripts|images paths, like Rails without sprockets.

module ActionView
  module Helpers
    module AssetTagHelper
      include TagHelper

      def compute_asset_path(source : String) : String
        return source if source.starts_with?('/') || source.includes?("://")
        "/#{yield source}"
      end

      def stylesheet_link_tag(*sources : String, **opts) : SafeString
        SafeString.new(sources.map { |src|
          %(<link rel="stylesheet" href="#{compute_asset_path(src) { |s| "stylesheets/#{s}.css" }}"#{tag_options(opts)} />)
        }.join("\n"))
      end

      def javascript_include_tag(*sources : String, **opts) : SafeString
        SafeString.new(sources.map { |src|
          %(<script src="#{compute_asset_path(src) { |s| "javascripts/#{s}.js" }}"></script>)
        }.join("\n"))
      end

      def image_tag(source : String, **opts) : SafeString
        AssetTagHelper.image_tag(source, __av_opts_to_h(opts))
      end

      # Static entry point for dom builders outside a view context
      # (ChatLayout-style modules); byte-identical to the instance form.
      # opts — pre-normalized Hash (use TagHelper.__av_normalize_val on
      # raw values), e.g. {"aria" => {"hidden" => "true"}, "size" => "20x20"}.
      def self.image_tag(source : String,
                         opts : Hash = {} of String => ::Nil) : SafeString
        attrs = {} of String => AttrVal
        opts = opts.transform_values { |v| TagHelper.__av_normalize_val(v) }
        alt_opt = opts.delete("alt")
        attrs["alt"] = alt_opt if alt_opt
        # compute_asset_path с images-префиксом (статик-контекст — без
        # yield-метода инстанса)
        attrs["src"] = (source.starts_with?('/') || source.includes?("://")) ? source : "/images/#{source}"
        if size_opt = opts.delete("size")
          parts = size_opt.to_s.split("x", 2)
          attrs["width"] = parts[0]
          attrs["height"] = parts[1]? || parts[0]
        end
        attrs.merge!(opts)
        SafeString.new(%(<img#{TagHelper.tag_options(attrs)} />))
      end

      def favicon_link_tag(source : String = "favicon.ico", **opts) : SafeString
        href = compute_asset_path(source) { |s| "images/#{s}" }
        SafeString.new(%(<link rel="icon" type="image/x-icon" href="#{href}"#{tag_options(opts)} />))
      end

      def javascript_tag(content : String) : SafeString
        SafeString.new("<script>\n//<![CDATA[\n#{content}\n//]]>\n</script>")
      end
    end
  end
end
