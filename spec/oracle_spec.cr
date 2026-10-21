# Oracle spec: the Crystal port must reproduce oracle/expected.yml
# exactly (captured from actionview 8.1.4 via oracle/cases.rb).
# Same case IDs, same expectations, no edits on either side.

require "spec"
require "../src/action_view_cr"

# --- expected.yml loader (values may span multiple lines) ---------
EXPECTED = begin
  hash = {} of String => String
  current_id : String? = nil
  File.read("#{__DIR__}/../oracle/expected.yml").each_line do |line|
    if line.includes?('\t')
      id, value = line.split('\t', 2)
      hash[id] = value.chomp
      current_id = id
    elsif cur = current_id
      hash[cur] = hash[cur] + "\n" + line.chomp
    end
  end
  hash
end

class PostModel
  include ActionView::FormModel

  property id : Int32?
  property title : String
  property body : String
  property published : Bool
  property visits : Int32?
  property due : Time?
  property author_id : Int32?

  def initialize(@id = nil, @title = "", @body = "", @published = false,
                 @visits = nil, @due = nil, @author_id = nil)
  end

  def form_scope : String
    "post"
  end

  def form_attributes : Hash(String, ActionView::FormValue)
    attrs = {} of String => ActionView::FormValue
    attrs["id"] = @id if @id
    attrs["title"] = @title
    attrs["body"] = @body
    attrs["published"] = @published
    attrs["visits"] = @visits if @visits
    attrs["due"] = @due if @due
    attrs["author_id"] = @author_id if @author_id
    attrs
  end

  def form_persisted? : Bool
    !id.nil?
  end

  def form_model_name : String
    "post"
  end

  def to_param : String
    id.to_s
  end
end

# Parent with a nested-attributes association for fields_for (the
# oracle's UserModel mimics accepts_nested_attributes_for :posts).
class UserModel
  include ActionView::FormModel

  property id : Int32?
  property name : String
  getter posts : Array(ActionView::FormModel)

  def initialize(@id = nil, @name = "", @posts = [] of ActionView::FormModel)
  end

  def form_scope : String
    "user"
  end

  def form_attributes : Hash(String, ActionView::FormValue)
    attrs = {} of String => ActionView::FormValue
    attrs["id"] = @id if @id
    attrs["name"] = @name
    attrs
  end

  def form_persisted? : Bool
    !id.nil?
  end

  def form_model_name : String
    "user"
  end

  def to_param : String
    id.to_s
  end

  def form_nested_children(assoc : String) : Array(ActionView::FormModel)?
    assoc == "posts" ? @posts : nil
  end
end

# Select-collection fixtures (fo_*/fs_* cases): the port's FormOption /
# GroupOption interfaces stand in for Rails' value_method/text_method.
class RoomOpt
  include ActionView::FormOption

  def initialize(@id : Int32, @name : String)
  end

  def option_value : String
    @id.to_s
  end

  def option_text : String
    @name
  end
end

class ContinentOpt
  include ActionView::GroupOption

  def initialize(@name : String, @countries : Array(ActionView::FormOption) =
                   [] of ActionView::FormOption)
  end

  def group_label : String
    @name
  end

  def group_options : Array(ActionView::FormOption)
    @countries
  end
end

ROOMS = [RoomOpt.new(1, "Alpha"), RoomOpt.new(2, "Beta")] of ActionView::FormOption
CONTINENTS = [
  ContinentOpt.new("Africa", [RoomOpt.new(1, "Egypt"), RoomOpt.new(4, "Rwanda")] of ActionView::FormOption),
  ContinentOpt.new("Asia",   [RoomOpt.new(3, "China"), RoomOpt.new(12, "India")] of ActionView::FormOption),
] of ActionView::GroupOption

# --- direct helper context ----------------------------------------
class OracleCtx
  include ActionView::Helpers
end

CTX = OracleCtx.new
POST = PostModel.new(id: 7, title: "Hi", body: "Words <b>here</b>", published: true,
                     visits: 42, due: Time.utc(2026, 1, 2, 12, 30))
PSEL = PostModel.new(id: 8, title: "T", author_id: 2)

# Polymorphic-path stub for the fw_poly_* cases — mirrors the oracle's
# POLY_ROUTES (resources :posts nested under resources :users). The
# real resolver is CRails::Routes::UrlHelpers (action_pack_cr), wired
# into FormHelper.polymorphic_path by railties_cr at boot.
ActionView::Helpers::FormHelper.polymorphic_path = ->(models : Array(ActionView::FormModel)) do
  names = models.map(&.form_model_name)
  last = models.last
  if names == ["post"]
    last.form_persisted? ? "/posts/#{last.to_param}" : "/posts"
  elsif names == ["user", "post"]
    "/users/#{models[0].to_param}/posts" + (last.form_persisted? ? "/#{last.to_param}" : "")
  else
    raise ArgumentError.new("no stubbed route for #{names}")
  end
end

# --- template-compiled view ---------------------------------------
class TplView
  include ActionView::Helpers

  getter post : PostModel
  getter post_new : PostModel
  getter post3 : PostModel
  getter user : UserModel
  getter np1 : PostModel
  getter np2 : PostModel
  getter post55 : PostModel
  getter c1 : PostModel
  getter psel : PostModel
  getter rooms : Array(ActionView::FormOption)
  getter continents : Array(ActionView::GroupOption)

  def initialize(@post, @post_new, @post3, @user, @np1, @np2, @post55, @c1, @psel,
                 @rooms : Array(ActionView::FormOption) = ROOMS,
                 @continents : Array(ActionView::GroupOption) = CONTINENTS)
  end

  compile_template "tpl_erb_escapes", "#{__DIR__}/fixtures/tpl/erb_escapes.html.erb"
  compile_template "tpl_erb_raw_ok", "#{__DIR__}/fixtures/tpl/erb_raw_ok.html.erb"
  compile_template "tpl_ct_block", "#{__DIR__}/fixtures/tpl/ct_block.html.erb"
  compile_template "tpl_ct_nested", "#{__DIR__}/fixtures/tpl/ct_nested.html.erb"
  compile_template "tpl_cycle", "#{__DIR__}/fixtures/tpl/cycle.html.erb"
  compile_template "tpl_current_cycle", "#{__DIR__}/fixtures/tpl/current_cycle.html.erb"
  compile_template "tpl_reset_cycle", "#{__DIR__}/fixtures/tpl/reset_cycle.html.erb"
  compile_template "tpl_link_block", "#{__DIR__}/fixtures/tpl/link_block.html.erb"
  compile_template "tpl_url_button_block", "#{__DIR__}/fixtures/tpl/url_button_block.html.erb"
  compile_template "tpl_url_button_block_delete", "#{__DIR__}/fixtures/tpl/url_button_block_delete.html.erb"
  compile_template "tpl_url_button_block_data", "#{__DIR__}/fixtures/tpl/url_button_block_data.html.erb"
  compile_template "tpl_fw_check_disabled", "#{__DIR__}/fixtures/tpl/fw_check_disabled.html.erb"
  compile_template "tpl_ff_hidden_no_ac", "#{__DIR__}/fixtures/tpl/ff_hidden_no_ac.html.erb"
  compile_template "tpl_form_tag", "#{__DIR__}/fixtures/tpl/form_tag.html.erb"
  compile_template "tpl_form_tag_method", "#{__DIR__}/fixtures/tpl/form_tag_method.html.erb"
  compile_template "tpl_button_block", "#{__DIR__}/fixtures/tpl/button_block.html.erb"
  compile_template "tpl_label_block", "#{__DIR__}/fixtures/tpl/label_block.html.erb"
  compile_template "tpl_fw_file_multipart", "#{__DIR__}/fixtures/tpl/fw_file_multipart.html.erb"
  compile_template "tpl_fw_check_values", "#{__DIR__}/fixtures/tpl/fw_check_values.html.erb"
  compile_template "tpl_fw_check_values_checked", "#{__DIR__}/fixtures/tpl/fw_check_values_checked.html.erb"
  compile_template "tpl_fw_no_block", "#{__DIR__}/fixtures/tpl/fw_no_block.html.erb"
  compile_template "tpl_fw_typed_text", "#{__DIR__}/fixtures/tpl/fw_typed_text.html.erb"
  compile_template "tpl_fw_typed_num", "#{__DIR__}/fixtures/tpl/fw_typed_num.html.erb"
  compile_template "tpl_fw_typed_date", "#{__DIR__}/fixtures/tpl/fw_typed_date.html.erb"
  compile_template "tpl_ff_radio_opts", "#{__DIR__}/fixtures/tpl/ff_radio_opts.html.erb"
  compile_template "tpl_ff_button", "#{__DIR__}/fixtures/tpl/ff_button.html.erb"
  compile_template "tpl_ff_button_block", "#{__DIR__}/fixtures/tpl/ff_button_block.html.erb"
  compile_template "tpl_ff_label_block", "#{__DIR__}/fixtures/tpl/ff_label_block.html.erb"
  compile_template "tpl_ff_field_id", "#{__DIR__}/fixtures/tpl/ff_field_id.html.erb"
  compile_template "tpl_ff_hidden_value", "#{__DIR__}/fixtures/tpl/ff_hidden_value.html.erb"
  compile_template "tpl_fs_select", "#{__DIR__}/fixtures/tpl/fs_select.html.erb"
  compile_template "tpl_fs_select_include_blank", "#{__DIR__}/fixtures/tpl/fs_select_include_blank.html.erb"
  compile_template "tpl_fs_select_prompt", "#{__DIR__}/fixtures/tpl/fs_select_prompt.html.erb"
  compile_template "tpl_fs_select_html_opts", "#{__DIR__}/fixtures/tpl/fs_select_html_opts.html.erb"
  compile_template "tpl_fs_select_multiple", "#{__DIR__}/fixtures/tpl/fs_select_multiple.html.erb"
  compile_template "tpl_fs_collection_select", "#{__DIR__}/fixtures/tpl/fs_collection_select.html.erb"
  compile_template "tpl_fs_collection_select_sel", "#{__DIR__}/fixtures/tpl/fs_collection_select_sel.html.erb"
  compile_template "tpl_fs_collection_prompt", "#{__DIR__}/fixtures/tpl/fs_collection_prompt.html.erb"
  compile_template "tpl_fs_grouped_select", "#{__DIR__}/fixtures/tpl/fs_grouped_select.html.erb"
  compile_template "tpl_fs_collection_checks", "#{__DIR__}/fixtures/tpl/fs_collection_checks.html.erb"
  compile_template "tpl_fs_collection_radios", "#{__DIR__}/fixtures/tpl/fs_collection_radios.html.erb"
  compile_template "tpl_fs_weekday", "#{__DIR__}/fixtures/tpl/fs_weekday.html.erb"
  compile_template "tpl_fw_local", "#{__DIR__}/fixtures/tpl/fw_local.html.erb"
  compile_template "tpl_fw_ids_model", "#{__DIR__}/fixtures/tpl/fw_ids_model.html.erb"
  compile_template "tpl_ff_password", "#{__DIR__}/fixtures/tpl/ff_password.html.erb"
  compile_template "tpl_ff_text_nil", "#{__DIR__}/fixtures/tpl/ff_text_nil.html.erb"
  compile_template "tpl_ff_textarea_value", "#{__DIR__}/fixtures/tpl/ff_textarea_value.html.erb"
  compile_template "tpl_fw_url", "#{__DIR__}/fixtures/tpl/fw_url.html.erb"
  compile_template "tpl_fw_model_new", "#{__DIR__}/fixtures/tpl/fw_model_new.html.erb"
  compile_template "tpl_fw_model", "#{__DIR__}/fixtures/tpl/fw_model.html.erb"
  compile_template "tpl_fw_poly_new", "#{__DIR__}/fixtures/tpl/fw_poly_new.html.erb"
  compile_template "tpl_fw_poly", "#{__DIR__}/fixtures/tpl/fw_poly.html.erb"
  compile_template "tpl_fw_poly_nested_new", "#{__DIR__}/fixtures/tpl/fw_poly_nested_new.html.erb"
  compile_template "tpl_fw_poly_nested", "#{__DIR__}/fixtures/tpl/fw_poly_nested.html.erb"
  compile_template "tpl_fw_label", "#{__DIR__}/fixtures/tpl/fw_label.html.erb"
  compile_template "tpl_fw_fields", "#{__DIR__}/fixtures/tpl/fw_fields.html.erb"
  compile_template "tpl_fw_field_name", "#{__DIR__}/fixtures/tpl/fw_field_name.html.erb"
  compile_template "tpl_content_for", "#{__DIR__}/fixtures/tpl/content_for.html.erb"
  compile_template "tpl_ff_view", "#{__DIR__}/fixtures/tpl/ff_view.html.erb"
  compile_template "tpl_ff_view_model", "#{__DIR__}/fixtures/tpl/ff_view_model.html.erb"
  compile_template "tpl_ff_view_scope_str", "#{__DIR__}/fixtures/tpl/ff_view_scope_str.html.erb"
  compile_template "tpl_ff_nested", "#{__DIR__}/fixtures/tpl/ff_nested.html.erb"
  compile_template "tpl_ff_nested_explicit", "#{__DIR__}/fixtures/tpl/ff_nested_explicit.html.erb"
  compile_template "tpl_ff_child_index", "#{__DIR__}/fixtures/tpl/ff_child_index.html.erb"
  compile_template "tpl_ff_destroy", "#{__DIR__}/fixtures/tpl/ff_destroy.html.erb"
  compile_template "tpl_ff_include_id_false", "#{__DIR__}/fixtures/tpl/ff_include_id_false.html.erb"
  compile_template "tpl_ff_non_nested", "#{__DIR__}/fixtures/tpl/ff_non_nested.html.erb"
  compile_template "tpl_cache_off", "#{__DIR__}/fixtures/tpl/cache_off.html.erb"
  compile_template "tpl_cache_off_if", "#{__DIR__}/fixtures/tpl/cache_off_if.html.erb"
  compile_template "tpl_cache_off_unless", "#{__DIR__}/fixtures/tpl/cache_off_unless.html.erb"
  compile_template "tpl_cache_on_hit_a", "#{__DIR__}/fixtures/tpl/cache_on_hit_a.html.erb"
  compile_template "tpl_cache_on_hit_b", "#{__DIR__}/fixtures/tpl/cache_on_hit_b.html.erb"
  compile_template "tpl_cache_on_cond_a", "#{__DIR__}/fixtures/tpl/cache_on_cond_a.html.erb"
  compile_template "tpl_cache_on_cond_b", "#{__DIR__}/fixtures/tpl/cache_on_cond_b.html.erb"
end

NP1 = PostModel.new(id: 101, title: "First")
NP2 = PostModel.new(title: "New one")
POST55 = PostModel.new(id: 55, title: "Explicit")
C1 = PostModel.new(id: 9, title: "Com")
U = UserModel.new(id: 5, name: "Oleg")
U.posts << NP1
U.posts << NP2

VIEW = TplView.new(POST, PostModel.new(title: "t"), PostModel.new(id: 3, title: "t"), U, NP1, NP2, POST55, C1, PSEL)

# --- partial-compiled view ----------------------------------------
class PartialView
  include ActionView::Helpers

  getter post : PostModel
  getter p1 : PostModel
  getter p2 : PostModel

  def initialize(@post, @p1, @p2)
  end

  compile_partials({
    "post" => {path: "#{__DIR__}/fixtures/partials/_post.html.erb", locals: {"post" => PostModel}},
    "row"  => {path: "#{__DIR__}/fixtures/partials/_row.html.erb",  locals: {"post" => PostModel, "post_counter" => Int32}},
    "wrap" => {path: "#{__DIR__}/fixtures/partials/_wrap.html.erb", locals: {"p" => PostModel}},
    "dash" => {path: "#{__DIR__}/fixtures/partials/_dash.html.erb", locals: {} of String => Nil},
  })
end

PV = PartialView.new(POST, PostModel.new(id: 1, title: "One"), PostModel.new(id: 2, title: "Two"))

T = Time.utc(2026, 1, 1, 12, 0, 0)

# id -> rendered result; raise ids would render as "raise:ClassName".
CASES = {
  # --- output safety ---
  "safe_html_safe"     => -> { "<b>hi</b>".html_safe.html_safe?.to_s },
  "safe_plain_not"     => -> { "<b>hi</b>".html_safe?.to_s },
  "safe_escape_once"   => -> { CTX.escape_once("1 &gt; 2 & 3") },
  "safe_raw"           => -> { CTX.raw("<b>x</b>").to_s },
  "safe_raw_html_safe" => -> { CTX.raw("<b>x</b>").html_safe?.to_s },
  "safe_join"          => -> { CTX.safe_join(["a", "<b>b</b>".html_safe, "c"], " | ").to_s },
  "safe_join_escapes"  => -> { CTX.safe_join(["<i>a</i>", "<b>b</b>".html_safe], ",").to_s },
  "tpl_erb_escapes"    => -> { VIEW.tpl_erb_escapes.to_s },
  "tpl_erb_raw_ok"     => -> { VIEW.tpl_erb_raw_ok.to_s },
  # --- tag ---
  "tag_br"              => -> { CTX.tag("br").to_s },
  "tag_img_src"         => -> { CTX.tag("img", src: "x.png", alt: "Pic").to_s },
  "tag_input_bool_true" => -> { CTX.tag("input", type: "checkbox", checked: true).to_s },
  "tag_input_bool_false" => -> { CTX.tag("input", type: "checkbox", checked: false).to_s },
  "tag_nil_value"       => -> { CTX.tag("img", src: nil, alt: "a").to_s },
  "tag_data_nested"     => -> { CTX.tag("div", data: {"remote" => "true", "url" => "/x"}).to_s },
  "tag_data_bool"       => -> { CTX.tag("div", data: {"boost" => true, "other" => false}, aria: {"busy" => true}, hidden: false).to_s },
  "tag_plain_bool_true" => -> { CTX.tag("div", data_visible: true, x_flag: false).to_s },
  "tag_aria_nested"     => -> { CTX.tag("div", aria: {"hidden" => "true"}).to_s },
  "tag_escape_values"   => -> { CTX.tag("img", alt: %(a"b&<c)).to_s },
  "tag_dot_form"        => -> { CTX.tag.br.to_s },
  "tag_dot_attrs"       => -> { CTX.tag.input(type: "text", disabled: true).to_s },
  "ct_block"            => -> { VIEW.tpl_ct_block.to_s },
  "ct_inline"           => -> { CTX.content_tag(:p, "hello", class: "x").to_s },
  "ct_nested"           => -> { VIEW.tpl_ct_nested.to_s },
  "ct_escapes"          => -> { CTX.content_tag(:p, "<script>").to_s },
  # --- text ---
  "txt_pluralize_1"     => -> { CTX.pluralize(1, "person") },
  "txt_pluralize_2"     => -> { CTX.pluralize(2, "person") },
  "txt_pluralize_count" => -> { CTX.pluralize(0, "person/plural") },
  "txt_truncate"        => -> { CTX.truncate("The quick brown fox jumps over the lazy dog", length: 20) },
  "txt_truncate_sep"    => -> { CTX.truncate("The quick brown fox jumps over the lazy dog", length: 20, separator: " ") },
  "txt_truncate_short"  => -> { CTX.truncate("short", length: 20) },
  "txt_truncate_escape" => -> { CTX.truncate("a<b>c" * 10, length: 12, escape: false) },
  "txt_excerpt"         => -> { CTX.excerpt("This is an example", "an", radius: 3) },
  "txt_highlight"       => -> { CTX.highlight("This is a beautiful morning", "beautiful") },
  "txt_highlight_multi" => -> { CTX.highlight("a b c", ["a", "c"]) },
  "txt_word_wrap"       => -> { CTX.word_wrap("one two three four five", line_width: 8) },
  "txt_simple_format"   => -> { CTX.simple_format("a\n\nb\n c") },
  "txt_simple_escapes"  => -> { CTX.simple_format("<b>a</b>") },
  "txt_cycle"           => -> { VIEW.tpl_cycle.to_s },
  "txt_current_cycle"   => -> { VIEW.tpl_current_cycle.to_s },
  "txt_reset_cycle"     => -> { VIEW.tpl_reset_cycle.to_s },
  "txt_dotw_words"      => -> { CTX.distance_of_time_in_words(T, Time.utc(2026, 1, 1, 12, 1, 30)) },
  "txt_dotw_hours"      => -> { CTX.distance_of_time_in_words(T, Time.utc(2026, 1, 1, 17, 0, 0)) },
  "txt_dotw_days"       => -> { CTX.distance_of_time_in_words(Time.utc(2026, 1, 1), Time.utc(2026, 1, 9)) },
  "txt_dotw_about_mo"   => -> { CTX.distance_of_time_in_words(Time.utc(2026, 1, 1), Time.utc(2026, 2, 3)) },
  "txt_dotw_seconds"    => -> { CTX.distance_of_time_in_words(T, Time.utc(2026, 1, 1, 12, 0, 25), include_seconds: true) },
  # --- numbers ---
  "num_currency"   => -> { CTX.number_to_currency(1234.5) },
  "num_delimiter"  => -> { CTX.number_with_delimiter(1234567) },
  "num_precision"  => -> { CTX.number_with_precision(3.14159, precision: 3) },
  "num_percentage" => -> { CTX.number_to_percentage(75.5) },
  "num_human_size" => -> { CTX.number_to_human_size(1048576) },
  "num_human"      => -> { CTX.number_to_human(1_500_000) },
  "num_phone"      => -> { CTX.number_to_phone(5551234567) },
  # --- url ---
  "url_link_plain"   => -> { CTX.link_to("Home", "/").to_s },
  "url_link_escapes" => -> { CTX.link_to(%q<a"b>, "/x?y=1").to_s },
  "url_link_attrs"   => -> { CTX.link_to("X", "/x", class: "btn", data: {"turbo" => "false"}).to_s },
  "url_link_block"   => -> { VIEW.tpl_link_block.to_s },
  "url_link_if_true" => -> { CTX.link_to_if(true, "Y", "/y").to_s },
  "url_link_if_false" => -> { CTX.link_to_if(false, "Y", "/y") { "(none)" } },
  "url_link_unless"  => -> { CTX.link_to_unless(false, "Z", "/z").to_s },
  "url_mail_to"      => -> { CTX.mail_to("me@example.com", "Me").to_s },
  "url_mail_to_emails" => -> { CTX.mail_to("me@example.com").to_s },
  "url_button_to"    => -> { CTX.button_to("Go", "/go").to_s },
  "url_button_method" => -> { CTX.button_to("Del", "/d", method: "delete").to_s },
  "url_button_block"        => -> { VIEW.tpl_url_button_block.to_s },
  "url_button_block_delete" => -> { VIEW.tpl_url_button_block_delete.to_s },
  "url_button_block_data"   => -> { VIEW.tpl_url_button_block_data.to_s },
  # --- assets ---
  "asset_css"         => -> { CTX.stylesheet_link_tag("a", "b").to_s },
  "asset_js"          => -> { CTX.javascript_include_tag("a", "b").to_s },
  "asset_image"       => -> { CTX.image_tag("x.png", alt: "X").to_s },
  "asset_image_size"  => -> { CTX.image_tag("x.png", size: "40x50").to_s },
  "asset_favicon"     => -> { CTX.favicon_link_tag.to_s },
  "asset_js_tag"      => -> { CTX.javascript_tag("alert(1)").to_s },
  # --- form tag helpers ---
  "ft_text_field"       => -> { CTX.text_field_tag("name", "val", class: "i").to_s },
  "ft_label"            => -> { CTX.label_tag("name", "Name").to_s },
  "ft_label_only"       => -> { CTX.label_tag("name").to_s },
  "ft_hidden"           => -> { CTX.hidden_field_tag("token", "abc").to_s },
  "ft_password"         => -> { CTX.password_field_tag("pw").to_s },
  "ft_email"            => -> { CTX.email_field_tag("email", "a@b.c").to_s },
  "ft_number"           => -> { CTX.number_field_tag("n", 5, min: 0, max: 10).to_s },
  "ft_date"             => -> { CTX.date_field_tag("d", "2026-01-02").to_s },
  "ft_check"            => -> { CTX.check_box_tag("ok", "1", true).to_s },
  "ft_check_false"      => -> { CTX.check_box_tag("ok", "1", false).to_s },
  "ft_radio"            => -> { CTX.radio_button_tag("g", "f", true).to_s },
  "ft_text_area"        => -> { CTX.text_area_tag("body", "hi", rows: 3).to_s },
  "ft_search"           => -> { CTX.search_field_tag("q", "x").to_s },
  "ft_tel"              => -> { CTX.telephone_field_tag("p", "123").to_s },
  "ft_url_field"        => -> { CTX.url_field_tag("u", "https://x.y").to_s },
  "ft_color"            => -> { CTX.color_field_tag("c", "#ffffff").to_s },
  "ft_range"            => -> { CTX.range_field_tag("r", 3, min: 0, max: 9).to_s },
  "ft_submit"           => -> { CTX.submit_tag("Save", class: "b").to_s },
  "ft_button"           => -> { CTX.button_tag("Cancel").to_s },
  "ft_button_value"     => -> { CTX.button_tag("Ok", value: "confirm").to_s },
  "ft_select"           => -> { CTX.select_tag("t", CTX.options_for_select([{"A", 1}, {"B", 2}], 2)).to_s },
  "ft_select_prompt"    => -> { CTX.select_tag("t", CTX.options_for_select([{"A", 1}]), prompt: "Pick").to_s },
  "ft_select_multiple"  => -> { CTX.select_tag("t", CTX.options_for_select([{"A", 1}, {"B", 2}]), multiple: true).to_s },
  "ft_options_selected" => -> { CTX.options_for_select(["a", "b"], "a").to_s },
  "ft_form_tag"         => -> { VIEW.tpl_form_tag.to_s },
  "ft_form_tag_method"  => -> { VIEW.tpl_form_tag_method.to_s },
  # --- form tag helpers (FORMS_SUPPORT phase 1) ---
  "ft_file_field"        => -> { CTX.file_field_tag("avatar", class: "i").to_s },
  "ft_file_field_accept" => -> { CTX.file_field_tag("avatar", accept: "image/png,image/jpeg").to_s },
  "ft_time_field"        => -> { CTX.time_field_tag("t", "12:30").to_s },
  "ft_time_time_value"   => -> { CTX.time_field_tag("t", Time.utc(2026, 1, 2, 12, 30, 45)).to_s },
  "ft_datetime_field"    => -> { CTX.datetime_field_tag("dt", "2026-01-02T12:30:00Z").to_s },
  "ft_datetime_local"    => -> { CTX.datetime_local_field_tag("dtl", "2026-01-02T12:30:00").to_s },
  "ft_month_field"       => -> { CTX.month_field_tag("m", "2026-01").to_s },
  "ft_week_field"        => -> { CTX.week_field_tag("w", "2026-W23").to_s },
  "ft_phone_field"       => -> { CTX.phone_field_tag("p", "555").to_s },
  "ft_image_submit"      => -> { CTX.image_submit_tag("icons/go.png").to_s },
  "ft_image_submit_alt"  => -> { CTX.image_submit_tag("icons/go.png", alt: "Custom").to_s },
  "ft_image_submit_abs"  => -> { CTX.image_submit_tag("/go.png").to_s },
  "ft_image_submit_url"  => -> { CTX.image_submit_tag("https://x.y/go.png").to_s },
  "ft_button_block"      => -> { VIEW.tpl_button_block.to_s },
  "ft_check_id_nil"      => -> { CTX.check_box_tag("user_ids[]", "5", true, id: nil, class: "sw").to_s },
  "ft_check_disabled"    => -> { CTX.check_box_tag("ok", "1", true, disabled: true).to_s },
  "ft_check_opts"        => -> { CTX.check_box_tag("ok", "1", true, class: "sw", id: "custom").to_s },
  "ft_radio_opts"        => -> { CTX.radio_button_tag("g", "f", true, class: "r").to_s },
  "ft_radio_disabled"    => -> { CTX.radio_button_tag("g", "f", false, disabled: true, id: nil).to_s },
  "ft_submit_turbo"      => -> { CTX.submit_tag("S", class: "b", data: {"turbo_submits_with" => "Working"}).to_s },
  "ft_select_disabled"   => -> { CTX.select_tag("t", CTX.options_for_select([{"A", 1}]), disabled: true).to_s },
  "ft_options_selected_array" => -> { CTX.options_for_select([{"A", 1}, {"B", 2}], [1, 2]).to_s },
  "ft_label_block"       => -> { VIEW.tpl_label_block.to_s },
  "ft_label_opts"        => -> { CTX.label_tag("name", "Name", class: "l").to_s },
  # --- form_with / FormBuilder ---
  "fw_url"         => -> { VIEW.tpl_fw_url.to_s },
  "fw_model_new"   => -> { VIEW.tpl_fw_model_new.to_s },
  "fw_model"       => -> { VIEW.tpl_fw_model.to_s },
  "fw_poly_new"    => -> { VIEW.tpl_fw_poly_new.to_s },
  "fw_poly"        => -> { VIEW.tpl_fw_poly.to_s },
  "fw_poly_nested_new" => -> { VIEW.tpl_fw_poly_nested_new.to_s },
  "fw_poly_nested" => -> { VIEW.tpl_fw_poly_nested.to_s },
  "fw_label"       => -> { VIEW.tpl_fw_label.to_s },
  "fw_fields"      => -> { VIEW.tpl_fw_fields.to_s },
  "fw_field_name"  => -> { VIEW.tpl_fw_field_name.to_s },
  # --- form_with / FormBuilder (FORMS_SUPPORT phase 3 + 4a) ---
  "fw_file_multipart"       => -> { VIEW.tpl_fw_file_multipart.to_s },
  "fw_check_values"         => -> { VIEW.tpl_fw_check_values.to_s },
  "fw_check_values_checked" => -> { VIEW.tpl_fw_check_values_checked.to_s },
  "fw_check_disabled"       => -> { VIEW.tpl_fw_check_disabled.to_s },
  "ff_hidden_no_ac"         => -> {
    ActionView::Helpers::FormTagHelper.remove_hidden_field_autocomplete = true
    begin
      VIEW.tpl_ff_hidden_no_ac.to_s
    ensure
      ActionView::Helpers::FormTagHelper.remove_hidden_field_autocomplete = false
    end
  },
  "fw_check_no_ac"          => -> {
    ActionView::Helpers::FormTagHelper.remove_hidden_field_autocomplete = true
    begin
      VIEW.tpl_fw_check_values.to_s
    ensure
      ActionView::Helpers::FormTagHelper.remove_hidden_field_autocomplete = false
    end
  },
  "fw_no_block"             => -> { VIEW.tpl_fw_no_block.to_s },
  "fw_typed_text"           => -> { VIEW.tpl_fw_typed_text.to_s },
  "fw_typed_num"            => -> { VIEW.tpl_fw_typed_num.to_s },
  "fw_typed_date"           => -> { VIEW.tpl_fw_typed_date.to_s },
  "ff_radio_opts"           => -> { VIEW.tpl_ff_radio_opts.to_s },
  "ff_button"               => -> { VIEW.tpl_ff_button.to_s },
  "ff_button_block"         => -> { VIEW.tpl_ff_button_block.to_s },
  "ff_label_block"          => -> { VIEW.tpl_ff_label_block.to_s },
  "ff_field_id"             => -> { VIEW.tpl_ff_field_id.to_s },
  "ff_hidden_value"         => -> { VIEW.tpl_ff_hidden_value.to_s },
  # --- FormOptionsHelper + select builders (phase 2 + 3.4) ---
  "fo_from_collection"      => -> { CTX.options_from_collection_for_select(ROOMS, 2).to_s },
  "fo_from_collection_none" => -> { CTX.options_from_collection_for_select(ROOMS).to_s },
  "fo_from_collection_dis"  => -> { CTX.options_from_collection_for_select(ROOMS, 2, disabled: 1).to_s },
  "fo_grouped"              => -> { CTX.grouped_options_for_select([{"G", [{"A", 1}, {"B", 2}] of (Tuple(String, Int32) | String)}, {"H", ["C"] of (Tuple(String, Int32) | String)}], 2).to_s },
  "fo_grouped_prompt"       => -> { CTX.grouped_options_for_select([{"G", [{"A", 1}] of (Tuple(String, Int32) | String)}], prompt: "Pick").to_s },
  "fo_option_groups"        => -> { CTX.option_groups_from_collection_for_select(CONTINENTS, 3).to_s },
  "fs_select"               => -> { VIEW.tpl_fs_select.to_s },
  "fs_select_include_blank" => -> { VIEW.tpl_fs_select_include_blank.to_s },
  "fs_select_prompt"        => -> { VIEW.tpl_fs_select_prompt.to_s },
  "fs_select_html_opts"     => -> { VIEW.tpl_fs_select_html_opts.to_s },
  "fs_select_multiple"      => -> { VIEW.tpl_fs_select_multiple.to_s },
  "fs_collection_select"    => -> { VIEW.tpl_fs_collection_select.to_s },
  "fs_collection_select_sel" => -> { VIEW.tpl_fs_collection_select_sel.to_s },
  "fs_collection_prompt"    => -> { VIEW.tpl_fs_collection_prompt.to_s },
  "fs_grouped_select"       => -> { VIEW.tpl_fs_grouped_select.to_s },
  "fs_collection_checks"    => -> { VIEW.tpl_fs_collection_checks.to_s },
  "fs_collection_radios"    => -> { VIEW.tpl_fs_collection_radios.to_s },
  "fs_weekday"              => -> { VIEW.tpl_fs_weekday.to_s },
  # --- app-config form semantics (local forms / ids / no utf8) ---
  "fw_local"     => -> {
    ActionView::Helpers::FormHelper.form_with_generates_remote_forms = false
    ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false
    ActionView::Helpers::FormHelper.form_with_generates_ids = true
    out = VIEW.tpl_fw_local.to_s
    ActionView::Helpers::FormHelper.form_with_generates_remote_forms = true
    ActionView::Helpers::FormTagHelper.default_enforce_utf8 = true
    ActionView::Helpers::FormHelper.form_with_generates_ids = false
    out
  },
  "fw_ids_model" => -> {
    ActionView::Helpers::FormHelper.form_with_generates_ids = true
    out = VIEW.tpl_fw_ids_model.to_s
    ActionView::Helpers::FormHelper.form_with_generates_ids = false
    out
  },
  "ff_password"  => -> { VIEW.tpl_ff_password.to_s },
  "ff_text_nil"  => -> { VIEW.tpl_ff_text_nil.to_s },
  "ff_textarea_value" => -> { VIEW.tpl_ff_textarea_value.to_s },
  # --- capture ---
  "cap_content_for" => -> { VIEW.tpl_content_for.to_s },
  # --- fields_for ---
  "ff_view"             => -> { VIEW.tpl_ff_view.to_s },
  "ff_view_model"       => -> { VIEW.tpl_ff_view_model.to_s },
  "ff_view_scope_str"   => -> { VIEW.tpl_ff_view_scope_str.to_s },
  "ff_nested"           => -> { VIEW.tpl_ff_nested.to_s },
  "ff_nested_explicit"  => -> { VIEW.tpl_ff_nested_explicit.to_s },
  "ff_child_index"      => -> { VIEW.tpl_ff_child_index.to_s },
  "ff_destroy"          => -> { VIEW.tpl_ff_destroy.to_s },
  "ff_include_id_false" => -> { VIEW.tpl_ff_include_id_false.to_s },
  "ff_non_nested"       => -> { VIEW.tpl_ff_non_nested.to_s },
  # --- fragment cache ---
  "cache_off"        => -> { VIEW.tpl_cache_off.to_s },
  "cache_off_if"     => -> { VIEW.tpl_cache_off_if.to_s },
  "cache_off_unless" => -> { VIEW.tpl_cache_off_unless.to_s },
  "cache_on_hit"     => -> {
    ActionView.perform_caching = true
    ActionView.cache_store = ActiveSupport::Cache.lookup_store(:memory_store)
    out = "#{VIEW.tpl_cache_on_hit_a}|#{VIEW.tpl_cache_on_hit_b}"
    ActionView.perform_caching = false
    out
  },
  "cache_on_cond"    => -> {
    ActionView.perform_caching = true
    ActionView.cache_store = ActiveSupport::Cache.lookup_store(:memory_store)
    out = "#{VIEW.tpl_cache_on_cond_a}|#{VIEW.tpl_cache_on_cond_a}|#{VIEW.tpl_cache_on_cond_b}"
    ActionView.perform_caching = false
    out
  },
  # --- partials ---
  "prt_locals"           => -> { PV.render(partial: "post", locals: {"post" => PV.post}).to_s },
  "prt_collection"       => -> { PV.render(partial: "post", collection: [PV.p1, PV.p2]).to_s },
  "prt_collection_empty" => -> { PV.render(partial: "post", collection: [] of PostModel).to_s },
  "prt_collection_as"    => -> { PV.render(partial: "row", collection: [PV.p1, PV.p2], as_local: "post").to_s },
  "prt_nested"           => -> { PV.render(partial: "wrap", locals: {"p" => PV.post}).to_s },
  "prt_spacer"           => -> { PV.render(partial: "post", collection: [PV.p1, PV.p2], spacer_template: "dash").to_s },
}

describe "action_view oracle (actionview 8.1.4)" do
  EXPECTED.each do |id, expected|
    it id do
      block = CASES[id]?
      block.should_not be_nil, "case #{id} not mirrored in spec"
      result = block.not_nil!.call.to_s
      result.strip.should eq(expected.strip), <<-MSG
        #{id}:
          expected: #{expected.inspect}
          got:      #{result.inspect}
        MSG
    end
  end

  it "mirrors every oracle case" do
    missing = EXPECTED.keys - CASES.keys
    extra = CASES.keys - EXPECTED.keys
    missing.should be_empty
    extra.should be_empty
  end

  # Rails 8.2 app behavior (the oracle gem is 8.1.4 and always emits
  # autocomplete="off"; the app oracle in capybara-tests/artifacts/rails
  # renders the _method hidden without it). Not oracle-drivable.
  it "omits autocomplete on _method when method_field_autocomplete is off" do
    ActionView::Helpers::FormHelper.form_with_generates_remote_forms = false
    ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false
    ActionView::Helpers::FormTagHelper.method_field_autocomplete = false
    result = VIEW.form_with(url: "/u/1", method: "delete").to_s
    ActionView::Helpers::FormTagHelper.method_field_autocomplete = true
    ActionView::Helpers::FormTagHelper.default_enforce_utf8 = true
    ActionView::Helpers::FormHelper.form_with_generates_remote_forms = true
    result.should eq(%(<form action="/u/1" accept-charset="UTF-8" method="post"><input type="hidden" name="_method" value="delete" />))
  end

  it "content_for stores content for the layout" do
    VIEW.tpl_content_for.to_s # run once to fill :sidebar
    VIEW.content_for(:sidebar).to_s.should eq("S")
    VIEW.content_for?(:sidebar).should be_true
  end
end
