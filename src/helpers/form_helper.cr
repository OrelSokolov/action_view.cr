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

    # Underscored singular model name ("post") — the polymorphic-path
    # input: [user, post] persisted → user_post_path(user, post), new →
    # user_posts_path(user). May differ from form_scope for namespaced
    # models, hence a separate method.
    abstract def form_model_name : String

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

      # Rails 8.1 defaults; apps on load_defaults 6.1+/8.x set these to
      # false/true respectively (local forms, generated ids).
      class_property form_with_generates_remote_forms = true
      class_property form_with_generates_ids = false

      # Polymorphic model→path resolver (the Rails polymorphic_path
      # analogue): installed by railties_cr at boot, pointing at
      # CRails::Routes::UrlHelpers. action_view_cr cannot see the route
      # set itself (the dependency runs the other way — action_pack_cr
      # depends on action_view_cr). nil → `form_with model:` without
      # `url:` raises ArgumentError.
      class_property polymorphic_path : (Array(FormModel) -> String)?

      # form_with model normalization: single record → [record]; nil →
      # []. The LAST model drives the scope and, via the polymorphic
      # resolver, the form action ([user, post] → post[title] fields
      # posted to /users/:user_id/posts, oracle fw_poly_*).
      # The array is handled structurally (Array, then cast per element):
      # a literal [message, Boost.new] is typed Array(Message | Boost) at
      # the call site — Crystal generics are invariant, so a
      # `when Array(FormModel)` branch would miss it.
      private def form_models(model : FormModel | Array | Nil) : Array(FormModel)
        case model
        when FormModel then [model] of FormModel
        when Array     then model.map { |m| m.as(FormModel) }
        else                [] of FormModel
        end
      end

      # form_with url: "/x" do |f| ... end — capture-first: the block is
      # rendered into a string before the open tag so file_field can
      # flip the multipart flag. Attribute order per Rails: user opts,
      # enctype, action, accept-charset, [data-remote], method (oracle
      # fw_local / fw_file_multipart). Returns "" — the whole form goes
      # to the output buffer in one piece.
      def form_with(url : String? = nil,
                    model : FormModel | Array | Nil = nil,
                    scope : String? = nil, **opts, &) : String
        models = form_models(model)
        scope ||= models.last?.try(&.form_scope)
        url ||= FormHelper.polymorphic_path.try(&.call(models)) unless models.empty?
        raise ArgumentError.new("form_with needs a url: or model:") unless url
        opts = __av_opts_to_h(opts)
        method = (opts.delete("method") || (models.last?.try(&.form_persisted?) ? "patch" : "post")).to_s
        builder = FormBuilder.new(self, scope || "", models.last?,
                                  emit_ids: FormHelper.form_with_generates_ids)
        body = capture { yield builder }
        enctype = builder.multipart? ? %( enctype="multipart/form-data") : ""
        __erb_out(String.build do |io|
          io << %(<form#{tag_options(opts)}#{enctype} action="#{HTML.escape(url)}" accept-charset="UTF-8")
          io << %( data-remote="true") if FormHelper.form_with_generates_remote_forms
          io << %( method="post">)
          io << __utf8_enrollment if FormTagHelper.default_enforce_utf8
          io << __av_method_field(method) unless method == "post"
          io << __csrf_token_field(url, method)
          io << body << "</form>"
        end)
        ""
      end

      # form_with without a block: opening tag + hidden fields only,
      # NO </form> (oracle fw_no_block) — the delete-form pattern.
      def form_with(url : String? = nil,
                    model : FormModel | Array | Nil = nil,
                    scope : String? = nil, **opts) : SafeString
        models = form_models(model)
        url ||= FormHelper.polymorphic_path.try(&.call(models)) unless models.empty?
        raise ArgumentError.new("form_with needs a url: or model:") unless url
        opts = __av_opts_to_h(opts)
        method = (opts.delete("method") || (models.last?.try(&.form_persisted?) ? "patch" : "post")).to_s
        SafeString.new(String.build do |io|
          io << %(<form#{tag_options(opts)} action="#{HTML.escape(url.to_s)}" accept-charset="UTF-8")
          io << %( data-remote="true") if FormHelper.form_with_generates_remote_forms
          io << %( method="post">)
          io << __utf8_enrollment if FormTagHelper.default_enforce_utf8
          io << __av_method_field(method) unless method == "post"
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

      # fields — form_with's scoped builder WITHOUT the form tag (Rails
      # 7.1+ fields; oracle fields_*). Unlike fields_for, ids follow the
      # form_with config (form_with_generates_ids), and model: may be an
      # array — the LAST model drives the scope. `url:` is accepted for
      # signature parity and ignored (no form tag to attach it to).
      def fields(scope : String? = nil, model : FormModel | Array | Nil = nil,
                 url : String? = nil, &) : String
        models = form_models(model)
        scope ||= models.last?.try(&.form_scope)
        yield FormBuilder.new(self, scope || "", models.last?,
                              emit_ids: FormHelper.form_with_generates_ids)
        ""
      end

      # form_for — the legacy form helper (oracle ffor_*): field ids
      # ALWAYS generated, dom class (edit_/new_ + the LAST model's
      # name) and dom id (edit_post_7 / new_post) on the form tag, local
      # form (no data-remote). `html:` opts merge in before
      # enctype/action — a user class REPLACES the dom class (Rails
      # semantics). Attribute order: class, id, [html opts], enctype,
      # action, accept-charset, method.
      def form_for(model : FormModel | Array, url : String? = nil,
                   html : Hash | NamedTuple | Nil = nil, &) : String
        models = form_models(model)
        last = models.last.not_nil!
        url ||= FormHelper.polymorphic_path.try(&.call(models))
        raise ArgumentError.new("form_for needs a url: or model: resolvable to a route") unless url
        persisted = last.form_persisted?
        method = persisted ? "patch" : "post"
        builder = FormBuilder.new(self, last.form_scope, last, emit_ids: true)
        body = capture { yield builder }
        name = last.form_model_name
        param = last.responds_to?(:to_param) ? last.to_param : last.to_s
        dom_class = persisted ? "edit_#{name}" : "new_#{name}"
        dom_id = persisted ? "edit_#{name}_#{param}" : "new_#{name}"
        html_h = html ? __av_opts_to_h(html) : {} of String => AttrVal
        merged = {} of String => AttrVal
        merged["class"] = html_h.delete("class") || dom_class
        merged["id"] = html_h.delete("id") || dom_id
        html_h.each { |k, v| merged[k] = v }
        merged["enctype"] = "multipart/form-data" if builder.multipart?
        __erb_out(String.build do |io|
          io << %(<form#{tag_options(merged)} action="#{HTML.escape(url)}" accept-charset="UTF-8")
          io << %( method="post">)
          io << __utf8_enrollment if FormTagHelper.default_enforce_utf8
          io << __av_method_field(method) unless method == "post"
          io << __csrf_token_field(url, method)
          io << body << "</form>"
        end)
        ""
      end

      # ————— ActionText lexxy editor (Rails 8.2 default) —————
      # rich_textarea_tag mirrors ActionText::TagHelper#rich_textarea_tag
      # with the lexxy editor: the <lexxy-editor> custom element, class
      # defaulting to "lexxy-content", name/value defaults, and
      # data-direct-upload-url / data-blob-url-template defaulting from
      # the host view context (Rails resolves them through
      # main_app.rails_direct_uploads_url / rails_service_blob_url —
      # override the two methods below; nil → attribute omitted).

      # Data-URL defaults for rich_textarea_tag; override in the host
      # view context.
      def rich_text_direct_upload_url : String?
        nil
      end

      def rich_text_blob_url_template : String?
        nil
      end

      def rich_textarea_tag(name : String, value : String? = nil, **opts) : SafeString
        SafeString.new(__av_lexxy_editor(name, value, __av_opts_to_h(opts)) { "" })
      end

      def rich_textarea_tag(name : String, value : String? = nil, **opts, &) : SafeString
        SafeString.new(__av_lexxy_editor(name, value, __av_opts_to_h(opts)) { capture { yield }.to_s })
      end

      # Shared open/close assembly: name defaults, a truthy value emits
      # the attribute, class falls back to "lexxy-content", the data
      # hash gains the two upload URLs unless already given. The block
      # body is NOT escaped (mention prompts and other tag helpers pass
      # SafeStrings, as with content_tag).
      def __av_lexxy_editor(name : String, value : String?, h : Hash(String, AttrVal), &)
        h["name"] = name unless h["name"]?
        h["value"] = value if value && !h["value"]?
        h["class"] = "lexxy-content" unless h["class"]?
        data = if (d = h["data"]?).is_a?(Hash)
                 d.as(Hash(String, AttrVal))
               else
                 nd = {} of String => AttrVal
                 h["data"] = nd
                 nd
               end
        unless (u = rich_text_direct_upload_url).nil? || data["direct_upload_url"]?
          data["direct_upload_url"] = u
        end
        unless (t = rich_text_blob_url_template).nil? || data["blob_url_template"]?
          data["blob_url_template"] = t
        end
        %(<lexxy-editor#{tag_options(h)}>#{yield}</lexxy-editor>)
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
          @scope.empty? ? attr : "#{@scope}[#{attr}]"
        end

        # Public field id (sanitized), emitted even in form_with
        # contexts where field ids are skipped (oracle ff_field_id);
        # for scope-less builders (form_with url:) the bare attr.
        def field_id(attr : String | Symbol) : String
          a = attr.to_s.chomp("?")
          return @view.__av_sanitize_id(a) if @scope.empty?
          scope = @scope.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").gsub(/_$/, "")
          "#{scope}_#{a}"
        end

        # id attribute, emitted only when the builder generates ids
        # (form_with: config-gated; fields_for: always) AND the caller
        # hasn't passed an explicit id: opt (Rails skip_default_ids
        # semantics). Same sanitization as Rails field_id:
        # "user[posts_attributes][0]" + "title" → "user_posts_attributes_0_title".
        private def id_attr(attr : String, explicit_id : Bool = false) : String
          return "" unless @emit_ids
          return "" if explicit_id
          %( id="#{field_id(attr)}")
        end

        def field_name(attr : String | Symbol) : SafeString
          SafeString.new(name_of(attr.to_s))
        end

        # Generic typed input — attribute order locked by the oracle
        # (fw_typed_*, fw_local): user opts (+size from maxlength),
        # type, value, name, id. `value_first` moves the (defaulted)
        # value before type (color_field / date-family quirk). A nil
        # value omits the attribute (Rails TextField).
        private def __ff_input(attr : String, type : String, field_value : String?,
                               *, value_first : Bool = false, **opts) : SafeString
          h = {} of String => AttrVal
          @view.__av_opts_to_h(opts).each { |k, v| h[k] = v }
          h["size"] = h["maxlength"] if h["maxlength"]? && !h["size"]?
          if value_first
            h["value"] = field_value unless h["value"]? || field_value.nil?
            h["type"] = type unless h["type"]?
          else
            h["type"] = type unless h["type"]?
            h["value"] = field_value unless h["value"]? || field_value.nil?
          end
          h["name"] = name_of(attr)
          SafeString.new(%(<input#{@view.tag_options(h)}#{id_attr(attr, h.has_key?("id"))} />))
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

        # nil stays nil (attribute omitted), everything else to_s.
        private def value_or_nil(attr : String) : String?
          case v = raw_value(attr)
          when Nil then nil
          else           v.to_s
          end
        end

        def text_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "text", value_or_nil(attr.to_s), **opts)
        end

        # Rails PasswordField: the object's value is never echoed —
        # value comes only from an explicit value: opt.
        def password_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "password", nil, **opts)
        end

        def email_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "email", value_or_nil(attr.to_s), **opts)
        end

        def search_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "search", value_or_nil(attr.to_s), **opts)
        end

        def telephone_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "tel", value_or_nil(attr.to_s), **opts)
        end

        def url_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "url", value_or_nil(attr.to_s), **opts)
        end

        def number_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "number", value_or_nil(attr.to_s), **opts)
        end

        def range_field(attr : String | Symbol, **opts) : SafeString
          __ff_input(attr.to_s, "range", value_or_nil(attr.to_s), **opts)
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
        # type, value, name, id. load_defaults 8.2 apps drop the
        # autocomplete via remove_hidden_field_autocomplete.
        def hidden_field(attr : String | Symbol, **opts) : SafeString
          @emitted_hidden_id = true if attr.to_s == "id" && @emit_ids
          h = {} of String => AttrVal
          h["autocomplete"] = "off" unless FormTagHelper.remove_hidden_field_autocomplete
          @view.__av_opts_to_h(opts).each { |k, v| h[k] = v }
          h["type"] = "hidden" unless h["type"]?
          h["value"] = value_of(attr.to_s) unless h["value"]?
          h["name"] = name_of(attr.to_s)
          SafeString.new(%(<input#{@view.tag_options(h)}#{id_attr(attr.to_s, h.has_key?("id"))} />))
        end

        # Positional values as named args (Crystal has no positional
        # options hash): check_box :role, checked_value: "administrator",
        # unchecked_value: "member". `include_hidden` toggles the
        # unchecked-value companion (Rails include_hidden); a `hidden`
        # opt passes through to the input as a boolean attribute, as in
        # Rails. `checked:` overrides the model-derived state (the
        # port's FormValue has no enum coercion — same deviation as
        # collection_check_boxes). Attribute order per oracle
        # (fw_check_values*, fw_check_disabled): hidden (name,
        # [disabled/form], type, value, autocomplete), then opts, type,
        # value, checked, name, id.
        def check_box(attr : String | Symbol, *, checked_value : String = "1",
                      unchecked_value : String = "0", include_hidden : Bool = true,
                      checked : Bool? = nil, **opts) : SafeString
          name = name_of(attr.to_s)
          v = raw_value(attr.to_s)
          checked = if checked.nil?
                      case v
                      when Bool then v
                      when Nil  then false
                      else           v.to_s == checked_value
                      end
                    else
                      checked
                    end
          h = @view.__av_opts_to_h(opts)
          SafeString.new(String.build do |io|
            if include_hidden
              companion = {"name" => name} of String => AttrVal
              {"disabled", "form"}.each { |k| companion[k] = h[k] if h[k]? }
              companion["type"] = "hidden"
              companion["value"] = unchecked_value
              companion["autocomplete"] = "off" unless FormTagHelper.remove_hidden_field_autocomplete
              io << %(<input#{@view.tag_options(companion)} />)
            end
            io << %(<input#{@view.tag_options(h)} type="checkbox" value="#{HTML.escape(checked_value)}")
            io << %( checked="checked") if checked
            io << %( name="#{name}"#{id_attr(attr.to_s, h.has_key?("id"))} />)
          end)
        end

        def radio_button(attr : String | Symbol, tag_value : String, **opts) : SafeString
          checked = value_of(attr.to_s) == tag_value ? %( checked="checked") : ""
          SafeString.new(%(<input#{@view.tag_options(opts)} type="radio" value="#{HTML.escape(tag_value)}"#{checked} name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s, opts.has_key?(:id))} />))
        end

        # --- select family (FORMS_SUPPORT phase 2 + 3.4) ---------------
        # Rails separates options/html_options as two positional hashes;
        # Crystal named args carry both — known form options are consumed
        # here, the rest go to the <select> tag.

        private def __fs_prompt_text(prompt : String | Bool) : String
          prompt == true ? "Please select" : prompt.to_s
        end

        # selected: explicit, else the model value ("" when nil — Rails
        # Tags::Select), coerced into the SelectValue union.
        private def __fs_selected(attr : String, selected : FormOptionsHelper::SelectValue?) : Tuple(FormOptionsHelper::SelectValue, Bool)
          value = selected || begin
            v = raw_value(attr)
            v.nil? ? "" : v
          end
          coerced = case value
                    when String, Int32, Int64 then value
                    else                           value.to_s
                    end
          {coerced, coerced.to_s.strip.empty?}
        end

        # include_blank / prompt prepending (SelectRenderer#add_options):
        # blank → <option value="" label=" "></option>, prompt only when
        # the field value is blank — both joined with "\n".
        private def __fs_add_options(option_tags : String | SafeString, include_blank : String | Bool | Nil,
                                     prompt : String | Bool | Nil, value_blank : Bool) : String
          tags = option_tags.to_s
          if include_blank
            content = include_blank.is_a?(String) ? include_blank : nil
            label = content ? nil : " "
            blank = content ? %(<option value="">#{HTML.escape(content)}</option>) : %(<option value="" label=" "></option>)
            tags = "#{blank}\n#{tags}"
          end
          if value_blank && prompt
            tags = %(<option value="">#{HTML.escape(__fs_prompt_text(prompt))}</option>) + "\n" + tags
          end
          tags
        end

        # <select> content: user opts, multiple, name (id last), with the
        # multiple hidden companion prepended — attribute orders locked
        # by oracle fs_select_*.
        private def __fs_select_tag(attr : String, option_tags : String, *, multiple : Bool,
                                    include_hidden : Bool, **html_opts) : SafeString
          h = {} of String => AttrVal
          @view.__av_opts_to_h(html_opts).each { |k, v| h[k] = v }
          h["multiple"] = true if multiple
          name = name_of(attr)
          html_name = multiple ? "#{name}[]" : name
          h["name"] = html_name
          select_html = %(<select#{@view.tag_options(h)}#{id_attr(attr, h.has_key?("id"))}>#{option_tags}</select>)
          if multiple && include_hidden
            companion = {"name" => html_name, "type" => "hidden", "value" => ""} of String => AttrVal
            companion["autocomplete"] = "off" unless FormTagHelper.remove_hidden_field_autocomplete
            hidden = %(<input#{@view.tag_options(companion)} />)
          else
            hidden = ""
          end
          SafeString.new(hidden + select_html)
        end

        def select(attr : String | Symbol, choices : Array, *,
                   selected : FormOptionsHelper::SelectValue? = nil,
                   disabled : FormOptionsHelper::SelectValue? = nil,
                   include_blank : String | Bool | Nil = nil,
                   prompt : String | Bool | Nil = nil,
                   multiple : Bool = false,
                   include_hidden : Bool = true,
                   **html_opts) : SafeString
          sel, blank = __fs_selected(attr.to_s, selected)
          tags = @view.options_for_select(choices, sel, disabled)
          tags = __fs_add_options(tags, include_blank, prompt, blank)
          __fs_select_tag(attr.to_s, tags, **html_opts, multiple: multiple,
                          include_hidden: include_hidden)
        end

        def collection_select(attr : String | Symbol, collection : Array(FormOption), *,
                              selected : FormOptionsHelper::SelectValue? = nil,
                              disabled : FormOptionsHelper::SelectValue? = nil,
                              include_blank : String | Bool | Nil = nil,
                              prompt : String | Bool | Nil = nil,
                              multiple : Bool = false,
                              include_hidden : Bool = true,
                              **html_opts) : SafeString
          sel, blank = __fs_selected(attr.to_s, selected)
          tags = @view.options_from_collection_for_select(collection, sel, disabled)
          tags = __fs_add_options(tags, include_blank, prompt, blank)
          __fs_select_tag(attr.to_s, tags, **html_opts, multiple: multiple,
                          include_hidden: include_hidden)
        end

        def grouped_collection_select(attr : String | Symbol, groups : Array(GroupOption), *,
                                      selected : FormOptionsHelper::SelectValue? = nil,
                                      include_blank : String | Bool | Nil = nil,
                                      prompt : String | Bool | Nil = nil,
                                      multiple : Bool = false,
                                      include_hidden : Bool = true,
                                      **html_opts) : SafeString
          sel, blank = __fs_selected(attr.to_s, selected)
          tags = @view.option_groups_from_collection_for_select(groups, sel)
          tags = __fs_add_options(tags, include_blank, prompt, blank)
          __fs_select_tag(attr.to_s, tags, **html_opts, multiple: multiple,
                          include_hidden: include_hidden)
        end

        WEEKDAYS_FROM_MONDAY = ["Monday", "Tuesday", "Wednesday", "Thursday",
                                "Friday", "Saturday", "Sunday"]

        def weekday_select(attr : String | Symbol, *,
                           selected : String? = nil,
                           multiple : Bool = false,
                           include_hidden : Bool = true,
                           **html_opts) : SafeString
          tags = WEEKDAYS_FROM_MONDAY.map { |d|
            sel = selected == d ? %( selected="selected") : ""
            %(<option value="#{d}"#{sel}>#{d}</option>)
          }.join("\n")
          __fs_select_tag(attr.to_s, tags, **html_opts, multiple: multiple,
                          include_hidden: include_hidden)
        end

        # Hidden companion (type, name, value, autocomplete — hidden_field_tag
        # with id nil) prepended, then checkbox + label per item with forced
        # ids (Rails skip_default_ids = false). Checked values come from the
        # `checked:` arg — FormValue has no array attributes (documented
        # deviation from Rails' object[method] arrays).
        def collection_check_boxes(attr : String | Symbol, collection : Array(FormOption), *,
                                   checked : Array(String) | Array(Int32) | Nil = nil,
                                   include_hidden : Bool = true,
                                   **html_opts) : SafeString
          name = "#{name_of(attr.to_s)}[]"
          base_id = field_id(attr)
          no_ac = FormTagHelper.remove_hidden_field_autocomplete
          hidden = include_hidden ? %(<input type="hidden" name="#{name}" value=""#{" autocomplete=\"off\"" unless no_ac} />) : ""
          checked_list = checked.try(&.map(&.to_s)) || [] of String
          body = collection.map { |e|
            v = e.option_value
            id = "#{base_id}_#{@view.__av_sanitize_id(v)}"
            chk = checked_list.includes?(v) ? %( checked="checked") : ""
            %(<input type="checkbox" value="#{HTML.escape(v)}"#{chk} name="#{name}" id="#{id}" /><label for="#{id}">#{HTML.escape(e.option_text)}</label>)
          }.join
          SafeString.new(hidden + body)
        end

        def collection_radio_buttons(attr : String | Symbol, collection : Array(FormOption),
                                     **html_opts) : SafeString
          name = name_of(attr.to_s)
          base_id = field_id(attr)
          current = raw_value(attr.to_s)
          no_ac = FormTagHelper.remove_hidden_field_autocomplete
          hidden = %(<input type="hidden" name="#{name}" value=""#{" autocomplete=\"off\"" unless no_ac} />)
          body = collection.map { |e|
            v = e.option_value
            id = "#{base_id}_#{@view.__av_sanitize_id(v)}"
            chk = current && current.to_s == v ? %( checked="checked") : ""
            %(<input type="radio" value="#{HTML.escape(v)}"#{chk} name="#{name}" id="#{id}" /><label for="#{id}">#{HTML.escape(e.option_text)}</label>)
          }.join
          SafeString.new(hidden + body)
        end

        # Rails Tags::TextArea: an explicit value: opt wins over the
        # object's attribute value; attribute order opts → name → id
        # (oracle ff_textarea_value).
        def text_area(attr : String | Symbol, **opts) : SafeString
          h = {} of String => AttrVal
          @view.__av_opts_to_h(opts).each { |k, v| h[k] = v }
          value = (v = h.delete("value")) ? v.to_s : value_of(attr.to_s)
          SafeString.new(%(<textarea#{@view.tag_options(h)} name="#{name_of(attr.to_s)}"#{id_attr(attr.to_s, h.has_key?("id"))}>\n#{HTML.escape(value)}</textarea>))
        end

        # ActionText Tags::ActionText (lexxy editor, Rails 8.2): name
        # from the scope, id when the builder emits ids (explicit id:
        # wins), an explicit value: opt wins over the object's
        # attribute; class/data defaults in rich_textarea_tag.
        def rich_text_area(attr : String | Symbol, **opts) : SafeString
          a = attr.to_s
          h = @view.__av_opts_to_h(opts)
          value = (v = h.delete("value")) ? v.to_s : value_or_nil(a)
          h["id"] = field_id(a) if @emit_ids && !h["id"]?
          SafeString.new(@view.__av_lexxy_editor(name_of(a), value, h) { "" })
        end

        def rich_text_area(attr : String | Symbol, **opts, &) : SafeString
          a = attr.to_s
          h = @view.__av_opts_to_h(opts)
          value = (v = h.delete("value")) ? v.to_s : value_or_nil(a)
          h["id"] = field_id(a) if @emit_ids && !h["id"]?
          SafeString.new(@view.__av_lexxy_editor(name_of(a), value, h) { @view.capture { yield }.to_s })
        end

        # Rails aliases rich_textarea ↔ rich_text_area.
        def rich_textarea(attr : String | Symbol, **opts) : SafeString
          rich_text_area(attr, **opts)
        end

        def rich_textarea(attr : String | Symbol, **opts, &) : SafeString
          rich_text_area(attr, **opts) { |form| yield form }
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

        # `for` is emitted when the builder generates ids (Rails label
        # respects skip_default_ids); opts render before it, as in
        # label_tag.
        private def label_for_attr(attr : String, explicit_for : Bool = false) : String
          return "" if explicit_for
          @emit_ids ? %( for="#{field_id(attr)}") : ""
        end

        def label(attr : String | Symbol, text : String? = nil, **opts) : SafeString
          SafeString.new(%(<label#{@view.tag_options(opts)}#{label_for_attr(attr.to_s, opts.has_key?(:for))}>#{HTML.escape(text || attr.to_s.gsub('_', ' ').capitalize)}</label>))
        end

        def label(attr : String | Symbol, **opts, &) : SafeString
          body = @view.capture { yield }
          SafeString.new(%(<label#{@view.tag_options(opts)}#{label_for_attr(attr.to_s, opts.has_key?(:for))}>#{body}</label>))
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
