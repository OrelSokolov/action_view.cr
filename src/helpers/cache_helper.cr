# Fragment cache — cache/cache_if/cache_unless (oracle: cache_* cases).
#
# Byte-exact with actionview 8.1.4 for explicit string keys: no
# template digest is added (Rails appends one only for templates with
# a virtual_path; port templates are compile-time methods with none —
# same as the gem's inline rendering). With caching off (the default,
# like Rails without a caching controller) the block is simply
# rendered.

module ActionView
  # Fragment-caching configuration. Rails reads perform_caching and
  # the store off the controller; the port has no controller layer
  # here, so it lives on the module. Defaults mirror an uncached app.
  class_property perform_caching : Bool = false
  class_property cache_store : ActiveSupport::Cache::Store =
    ActiveSupport::Cache.lookup_store(:null_store)

  module Helpers
    module CacheHelper
      # cache("key") { ... } — the block's output goes to the page
      # buffer and is stored under the fragment key; a hit replays the
      # stored content. Returns "" (the block content is concatenated,
      # like Rails' safe_concat).
      def cache(name : String? = nil, *, expires_in : Time::Span? = nil, &) : String
        if ActionView.perform_caching
          key = fragment_cache_key(name)
          if (hit = ActionView.cache_store.read(key))
            __erb_out(hit)
          else
            content = capture { yield }
            ActionView.cache_store.write(key, content, expires_in)
            __erb_out(content)
          end
        else
          yield
        end
        ""
      end

      def cache_if(condition : Bool, name : String? = nil, *, expires_in : Time::Span? = nil, &) : String
        if condition
          cache(name, expires_in: expires_in) { yield }
        else
          yield
          ""
        end
      end

      def cache_unless(condition : Bool, name : String? = nil, *, expires_in : Time::Span? = nil, &) : String
        cache_if(!condition, name, expires_in: expires_in) { yield }
      end

      # Explicit string keys pass through unchanged.
      def fragment_cache_key(name : String?) : String
        name.to_s
      end
    end
  end
end
