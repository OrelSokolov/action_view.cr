# FormHelper / FormBuilder — byte-exact with actionview 8.1.4 (oracle:
# fw_* and ff_* cases). Models expose form metadata through the
# FormModel interface; ActiveRecord::Base implements it via its
# attributes hash.

module ActionView
  alias FormValue = String | Int32 | Int64 | Float64 | Bool | Time | Nil

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

      # form_with url: "/x" do |f| ... end — capture-first: the block is
      # rendered into a string before the open tag so file_field can
      # flip the multipart flag (enctype is the FIRST form attribute,
      # oracle fw_file_multipart). Returns "" — the whole form goes to
      # the output buffer in one piece.
      def form_with(url : String? = nil, model : FormModel? = nil,
                    scope : String? = nil, **opts, &) : String
        scope = model.form_scope if model && !scope
        raise ArgumentError.new("form_with needs a url: or model:") unless url
        opts = __av_opts_to_h(opts)
        method = (opts.delete("method") || (model.try(&.form_persisted?) ? "patch" : "post")).to_s
        builder = FormBuilder.new(self, scope || "", model)
        body = capture { yield builder }
        enctype = builder.multipart? ? %( enctype="multipart/form-data") : ""
        __erb_out(String.build do |io|
          io << %(<form#{enctype} action="#{HTML.escape(url)}" accept-charset="UTF-8"#{tag_options(opts)} data-remote="true" method="post">)
          io << UTF8_ENROLLMENT
          io << %(<input type="hidden" name="_method" value="#{method}" autocomplete="off" />) unless method == "post"
          io << __csrf_token_field(url, method)
          io << body << "</form>"
        end)
        ""
      end

      # form_with without a block: opening tag + hidden fields only,
      # NO </form> (oracle fw_no_block) — the delete-form pattern.
      def form_with(url : String? = nil, model : FormModel? = nil,
                    scope : String? = nil, **opts) : SafeString
        opts = __av_opts_to_h(opts)
        method = (opts.delete("method") || (model.try(&.form_persisted?) ? "patch" : "post")).to_s
        SafeString.new(String.build do |io|
          io << %(<form action="#{HTML.escape(url.to_s)}" accept-charset="UTF-8"#{tag_options(opts)} data-remote="true" method="post">)
          io << UTF8_ENROLLMENT
          io << %(<input type="hidden" name="_method" value="#{method}" autocomplete="off" />) unless method == "post"
          io << __csrf_token_field(url.to_s, method)
        end)
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
          @multipart = false
        end

        def emitted_hidden_id? : Bool
          @emitted_hidden_id
        end

        # Set by file_field; form_with reads it after the block to emit
        # enctype="multipart/form-data".
        def multipart? : Bool
          @multipart
        end

        private def value_of(attr : String) : String
          v = @model.try(&.form_attributes[attr]?)
          v.nil? ? "" : v.to_s
        end

        private def raw_value(attr : String) : FormValue
          @model.try(&.form_attributes[attr]?) || nil
        end

        private def name_of(attr : String) : String
          "#{@scope}[#{attr}]"
        end

        # Public field id (sanitized), emitted even in form_with
        # contexts where field ids are skipped (oracle ff_field_id).
        def field_id(attr : String | Symbol) : String
          return "" if @scope.empty?
          scope = @scope.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").gsub(/_$/, "")
          "#{scope}_#{attr.to_s.chomp("?")}"
        end

        # id attribute, emitted only in fields_for builders (form_with
        # fields stay id-less). Same sanitization as Rails field_id:
        # "user[posts_attributes][0]" + "title" →
        # "user_posts_attributes_0_title".
        private def id_attr(attr : String) : String
          return "" unless @emit_ids && !@scope.empty?
          %( id="#{field_id(attr)}")
        end

        def field_name(attr : String | Symbol) : SafeString
          SafeString.new(name_of(attr.to_s))
        end

        # Generic typed input — attribute order locked by the oracle
        # (fw_typed_*): user opts, type, value, name, id. `value_first`
        # moves the (defaulted) value before type (color_field quirk).
        private def __ff_input(attr : String, type : String, value : String?,
                               *, value_first : Bool = false, **opts) : SafeString
          h = {} of String => AttrVal
          @view.__av_opts_to_h(opts).each { |k, v| h[k] = v }
          if value_first
            h["value"] = value unless h["value"]? || value.nil?
            h["type"] = type unless h["type"]?
          else
            h["type"] = type unless h["type"]?
            h["value"] = value unless h["value"]? || value.nil?
          end
          h["name"] = name_of(attr)
          SafeString.new(%(<input#{@view.tag_options(h)}#{id_attr(attr)} />))
        end

        # ISO-style formatting of Time values for the date/time fields
        # (oracle fw_typed_date).
        private def format_time(v : Time, kind : String) : String
          case kind
          when "date"            then v.to_s("%F")
          when "time"            then v.to_s("%H:%M:%S.%L")
          when "datetime-local"  then v.to_s("%FT%T")
          when "month"           then v.to_s("%Y-%m")
          when "week"            then v.to_s("%G-W%V")
          else                        v.to_s
          end
        end

        private def typed_value(attr : String, type : String) : String?
          case v = raw_value(attr)
          when Time then format_time(v, type)
          when Nil  then nil
          else           v.to_s
          end
        end

        def text_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "text", value_of(attr.to_s), **opts)
        end

        def password_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "password", value_of(attr.to_s), **opts)
        end

        def email_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "email", value_of(attr.to_s), **opts)
        end

        def search_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "search", value_of(attr.to_s), **opts)
        end

        def telephone_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "tel", value_of(attr.to_s), **opts)
        end

        def url_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "url", value_of(attr.to_s), **opts)
        end

        def number_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "number", value_of(attr.to_s), **opts)
        end

        def range_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "range", value_of(attr.to_s), **opts)
        end

        def date_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "date", typed_value(attr.to_s, "date"), **opts, value_first: true)
        end

        def time_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "time", typed_value(attr.to_s, "time"), **opts, value_first: true)
        end

        # Rails 8.1: datetime_field renders type="datetime-local".
        def datetime_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "datetime-local", typed_value(attr.to_s, "datetime-local"), **opts, value_first: true)
        end

        def datetime_local_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "datetime-local", typed_value(attr.to_s, "datetime-local"), **opts, value_first: true)
        end

        def month_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "month", typed_value(attr.to_s, "month"), **opts, value_first: true)
        end

        def week_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "week", typed_value(attr.to_s, "week"), **opts, value_first: true)
        end

        # Invalid colors default to #000000; the value attribute is
        # emitted BEFORE type (oracle fw_typed_text).
        def color_field(attr : String | Symbol, **opts) : SafeString
          v = value_of(attr.to_s)
          color = v =~ /\A#[0-9a-fA-F]{6}\z/ ? v : "#000000"
          __ff_input(attr.to_s, "color", color, **opts, value_first: true)
        end

        # Opts first, no value, flips the form's multipart flag.
        def file_field(attr : String | Symbol, **opts) : SafeString
          @multipart = true
          __ff_input(attr.to_s, "file", nil, **opts)
        end

        # Attribute order per oracle (ff_hidden_value, fw_fields):
        # autocomplete, user opts (an explicit value: slots in here),
        # type, value, name, id.
        def hidden_field(attr : String | Symbol, **opts) : SafeString
          @emitted_hidden_id = true if attr.to_s == "id" && @emit_ids
          h = {"autocomplete" => "off"} of String => AttrVal
          @view.__av_opts_to_h(opts).each { |k, v| h[k] = v }
          h["type"] = "hidden" unless h["type"]?
          h["value"] = value_of(attr.to_s) unless h["value"]?
          h["name"] = name_of(attr.to_s)
          SafeString.new(%(<input#{@view.tag_options(h)}#{id_attr(attr.to_s)} />))
        end

        # Positional values as named args (Crystal has no positional
        # options hash): check_box :role, checked_value: "administrator",
        # unchecked_value: "member". Attribute order per oracle
        # (fw_check_values*): hidden (name, type, value, autocomplete),
        # then opts, type, value, checked, name, id.
        def check_box(attr : String | Symbol, *, checked_value : String = "1",
                      unchecked_value : String = "0", hidden : Bool = true, **opts) : SafeString
          name = name_of(attr.to_s)
          v = raw_value(attr.to_s)
          checked = case v
                    when Bool then v
                    when Nil  then false
                    else           v.to_s == checked_value
                    end
          SafeString.new(String.build do |io|
            io << %(<input name="#{name}" type="hidden" value="#{HTML.escape(unchecked_value)}" autocomplete="off" />) if hidden
            io << %(<input#{@view.tag_options(opts)} type="checkbox" value="#{HTML.escape(checked_value)}")
            io << %( checked="checked") if checked
            io << %( name="#{name}"#{id_attr(attr.to_s)} />)
          end)
        end

        def radio_button(attr : String | Symbol, tag_value : String, **opts) : SafeString
          checked = value_of(attr.to_s) == tag_value ? %( checked="checked") : ""
          SafeString.new(%(<input#{@view.tag_options(opts)} type="radio" value="#{HTML.escape(tag_value)}"#{checked} name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s)} />))
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
                @view.__erb_out(builder.hidden_field("id"))
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

        def label(attr : String | Symbol, **opts, &) : SafeString
          body = @view.capture { yield }
          SafeString.new(%(<label#{@view.tag_options(opts)}>#{body}</label>))
        end

        # Default caption uses I18n model names in Rails ("Update Post");
        # the port takes an explicit caption or a block.
        def button(content : String, **opts) : SafeString
          h = {"name" => "button", "type" => "submit"} of String => AttrVal
          @view.__av_opts_to_h(opts).each { |k, v| h[k] = v }
          SafeString.new(%(<button#{@view.tag_options(h)}>#{HTML.escape(content)}</button>))
        end

        def button(**opts, &) : SafeString
          h = {"name" => "button", "type" => "submit"} of String => AttrVal
          @view.__av_opts_to_h(opts).each { |k, v| h[k] = v }
          body = @view.capture { yield }
          SafeString.new(%(<button#{@view.tag_options(h)}>#{body}</button>))
        end

        def submit(value : String = "Save changes", **opts) : SafeString
          SafeString.new(%(<input type="submit" name="commit" value="#{HTML.escape(value)}"#{@view.tag_options(opts)} data-disable-with="#{HTML.escape(value)}" />))
        end
      end
    end
  end
end
