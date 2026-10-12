# FormHelper / FormBuilder — byte-exact with actionview 8.1.4 (oracle:
# fw_* and ff_* cases). Models expose form metadata through the
# FormModel interface; ActiveRecord::Base implements it via its
# attributes hash.

module ActionView
  alias FormValue = String | Int32 | Int64 | Float64 | Bool | Nil

  module FormModel
    abstract def form_scope : String
    abstract def form_attributes : Hash(String, FormValue)
    abstract def form_persisted? : Bool

    # Nested-attributes associations for FormBuilder#fields_for — the
    # counterpart of AR's accepts_nested_attributes_for. Override to
    # return the child records of `assoc`; nil (default) means the name
    # is not a nested-attributes association and fields_for falls back
    # to plain scope nesting.
    def form_nested_children(assoc : String) : Array(FormModel)?
      nil
    end
  end

  module Helpers
    module FormHelper
      include TagHelper
      include FormTagHelper

      # form_with url: "/x" do |f| ... end — same buffer contract as
      # form_tag (open tags, yield, close, return "").
      def form_with(url : String? = nil, model : FormModel? = nil,
                    scope : String? = nil, **opts, &) : String
        scope = model.form_scope if model && !scope
        raise ArgumentError.new("form_with needs a url: or model:") unless url
        opts = __av_opts_to_h(opts)
        method = model.try(&.form_persisted?) ? "patch" : "post"
        __av_out(String.build do |io|
          io << %(<form action="#{HTML.escape(url)}" accept-charset="UTF-8"#{tag_options(opts)} data-remote="true" method="post">)
          io << UTF8_ENROLLMENT
          io << %(<input type="hidden" name="_method" value="#{method}" autocomplete="off" />) unless method == "post"
          io << __csrf_token_field(url, method)
        end)
        yield FormBuilder.new(self, scope || "", model)
        __av_out "</form>"
        ""
      end

      # fields_for — view-level scoped fields without a form tag
      # (oracle: ff_view* cases). Like form_with's builder, except ids
      # ARE generated (Rails fields_for resets skip_default_ids).
      def fields_for(scope : String | Symbol, model : FormModel? = nil, &) : String
        yield FormBuilder.new(self, scope.to_s, model, emit_ids: true)
        ""
      end

      def fields_for(model : FormModel, &) : String
        yield FormBuilder.new(self, model.form_scope, model, emit_ids: true)
        ""
      end

      class FormBuilder
        def initialize(@view : ActionView::Helpers, @scope : String,
                       @model : FormModel? = nil, @emit_ids : Bool = false)
          @nested_child_index = {} of String => Int32
          @emitted_hidden_id = false
        end

        def emitted_hidden_id? : Bool
          @emitted_hidden_id
        end

        private def value_of(attr : String) : String
          v = @model.try(&.form_attributes[attr]?)
          v.nil? ? "" : v.to_s
        end

        private def name_of(attr : String) : String
          "#{@scope}[#{attr}]"
        end

        # id attribute, emitted only in fields_for builders (form_with
        # fields stay id-less). Same sanitization as Rails field_id:
        # "user[posts_attributes][0]" + "title" →
        # "user_posts_attributes_0_title".
        private def id_attr(attr : String) : String
          return "" unless @emit_ids && !@scope.empty?
          scope = @scope.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").gsub(/_$/, "")
          %( id="#{scope}_#{attr.chomp("?")}")
        end

        def field_name(attr : String | Symbol) : SafeString
          SafeString.new(name_of(attr.to_s))
        end

        def text_field(attr : String | Symbol, **opts) : SafeString
          SafeString.new(%(<input type="text" value="#{HTML.escape(value_of(attr.to_s))}" name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s)}#{@view.tag_options(opts)} />))
        end

        def password_field(attr : String | Symbol, **opts) : SafeString
          SafeString.new(%(<input type="password" value="#{HTML.escape(value_of(attr.to_s))}" name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s)}#{@view.tag_options(opts)} />))
        end

        def hidden_field(attr : String | Symbol, **opts) : SafeString
          @emitted_hidden_id = true if attr.to_s == "id" && @emit_ids
          SafeString.new(%(<input autocomplete="off" type="hidden" value="#{HTML.escape(value_of(attr.to_s))}" name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s)}#{@view.tag_options(opts)} />))
        end

        def check_box(attr : String | Symbol, **opts) : SafeString
          checked = truthy?(@model.try(&.form_attributes[attr]?)) ? %( checked="checked") : ""
          SafeString.new(
            %(<input name="#{name_of(attr.to_s)}" type="hidden" value="0" autocomplete="off" />) +
            %(<input type="checkbox" value="1"#{checked} name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s)}#{@view.tag_options(opts)} />))
        end

        def radio_button(attr : String | Symbol, tag_value : String, **opts) : SafeString
          checked = value_of(attr) == tag_value ? %( checked="checked") : ""
          SafeString.new(%(<input type="radio" value="#{tag_value}"#{checked} name="#{name_of(attr.to_s)}"#{@view.tag_options(opts)} />))
        end

        def text_area(attr : String | Symbol, **opts) : SafeString
          SafeString.new(%(<textarea name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s)}#{@view.tag_options(opts)}>\n#{HTML.escape(value_of(attr.to_s))}</textarea>))
        end

        # fields_for — nested forms (oracle: ff_nested*, ff_child_index,
        # ff_destroy cases). Nested-attributes naming
        # user[posts_attributes][0][title] when the parent exposes the
        # association through FormModel#form_nested_children, with a
        # sequential per-association index and an automatic hidden id
        # appended AFTER the block for persisted children (Rails:
        # emit_hidden_id); otherwise plain scope nesting
        # (user[comment][title]).
        def fields_for(assoc : String | Symbol, record : FormModel? = nil, *,
                       child_index : Int32 | String? = nil, include_id : Bool = true, &) : String
          name = assoc.to_s
          nested = @model.try(&.form_nested_children(name))

          if nested
            records = [] of FormModel
            record ? records << record : nested.each { |child| records << child }
            records.each do |child|
              index = child_index || next_child_index(name)
              builder = FormBuilder.new(@view, "#{@scope}[#{name}_attributes][#{index}]", child, emit_ids: true)
              yield builder
              if include_id && child.form_persisted? && !builder.emitted_hidden_id?
                @view.__av_out(builder.hidden_field("id"))
              end
            end
          else
            yield FormBuilder.new(@view, "#{@scope}[#{name}]", record, emit_ids: true)
          end
          ""
        end

        private def next_child_index(name : String) : Int32
          @nested_child_index[name] = (@nested_child_index[name]? || -1) + 1
        end

        def label(attr : String | Symbol, text : String? = nil, **opts) : SafeString
          SafeString.new(%(<label#{@view.tag_options(opts)}>#{HTML.escape(text || attr.to_s.gsub('_', ' ').capitalize)}</label>))
        end

        def submit(value : String = "Save changes", **opts) : SafeString
          SafeString.new(%(<input type="submit" name="commit" value="#{HTML.escape(value)}"#{@view.tag_options(opts)} data-disable-with="#{HTML.escape(value)}" />))
        end

        private def truthy?(value : FormValue) : Bool
          case value
          when Bool then value
          when String then value == "true" || value == "1"
              else !!value
          end
        end
      end
    end
  end
end
