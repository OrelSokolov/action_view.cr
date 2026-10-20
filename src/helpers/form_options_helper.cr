# FormOptionsHelper — byte-exact with actionview 8.1.4 (oracle: fo_*,
# fs_* cases). options_for_select lives here (as in Rails) and is
# included by FormTagHelper; the collection-based builders use the
# FormOption/GroupOption interfaces instead of Rails' value_method/
# text_method symbols (Crystal has no dynamic dispatch) — a documented
# 1:1 deviation.

module ActionView
  # Element of a select collection: value + text of one <option>.
  module FormOption
    abstract def option_value : String
    abstract def option_text : String
  end

  # Element of a grouped select: one <optgroup>.
  module GroupOption
    abstract def group_label : String
    abstract def group_options : Array(FormOption)
  end

  module Helpers
    module FormOptionsHelper
      include TagHelper

      alias SelectValue = String | Int32 | Int64 | Array(String) | Array(Int32)

      private def __fo_value_list(v) : Array(String)?
        case v
        when Array then v.map(&.to_s)
        when Nil   then nil
        else            [v.to_s]
        end
      end

      # <option> tags from [text, value] pairs (or plain strings used
      # for both); selected/disabled first, then value — Rails hash
      # insertion order, oracle fo_from_collection_dis.
      def options_for_select(container : Array, selected : SelectValue? = nil,
                             disabled : SelectValue? = nil) : SafeString
        sel = __fo_value_list(selected)
        dis = __fo_value_list(disabled)
        SafeString.new(container.map { |item|
          label, value = item.is_a?(Tuple) || item.is_a?(Array) ? {item[0].to_s, item[1].to_s} : {item.to_s, item.to_s}
          attrs = String.build do |io|
            io << %( selected="selected") if sel.try(&.includes?(value))
            io << %( disabled="disabled") if dis.try(&.includes?(value))
          end
          %(<option#{attrs} value="#{HTML.escape(value)}">#{HTML.escape(label)}</option>)
        }.join("\n"))
      end

      def options_from_collection_for_select(collection : Array(FormOption),
                                             selected : SelectValue? = nil,
                                             disabled : SelectValue? = nil) : SafeString
        options_for_select(
          collection.map { |e| {e.option_text, e.option_value} },
          selected, disabled)
      end

      def option_groups_from_collection_for_select(groups : Array(GroupOption),
                                                   selected : SelectValue? = nil) : SafeString
        SafeString.new(groups.map { |g|
          %(<optgroup label="#{HTML.escape(g.group_label)}">#{options_from_collection_for_select(g.group_options, selected)}</optgroup>)
        }.join)
      end

      def grouped_options_for_select(grouped : Array(Tuple(String, Array)),
                                     selected : SelectValue? = nil,
                                     *, prompt : String? = nil) : SafeString
        sel = __fo_value_list(selected)
        SafeString.new(String.build do |io|
          io << %(<option value="">#{HTML.escape(prompt)}</option>) if prompt && !prompt.empty?
          grouped.each do |(label, container)|
            io << %(<optgroup label="#{HTML.escape(label)}">#{options_for_select(container, sel)}</optgroup>)
          end
          end)
      end
    end
  end
end
