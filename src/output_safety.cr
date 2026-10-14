# Output-safety helpers. SafeString и String#html_safe/#html_safe? —
# в erb_cr; здесь — ActionView-хелперы поверх контракта (как raw /
# escape_once / safe_join в Rails OutputSafetyHelper/TagHelper).

module ActionView
  module Helpers
    # Marks a string as trusted HTML: `<%= raw x %>` appends it as-is.
    def raw(value : String) : SafeString
      SafeString.new(value)
    end

    def raw(value : SafeString) : SafeString
      value
    end

    def html_escape(value : String) : String
      HTML.escape(value)
    end

    # `&` untouched when it already starts an entity (`&amp;` etc.).
    def escape_once(value : String) : String
      value.gsub(/&(?!([a-zA-Z]+|#\d+);)/, "&amp;")
        .gsub('<', "&lt;")
        .gsub('>', "&gt;")
        .gsub('"', "&quot;")
        .gsub('\'', "&#39;")
    end

    # Escapes unsafe elements, passes SafeString through untouched.
    def safe_join(elements : Array(String | SafeString), separator : String = "") : SafeString
      SafeString.new(elements.map { |e|
        e.is_a?(SafeString) ? e.raw : HTML.escape(e.to_s)
      }.join(separator))
    end
  end
end
