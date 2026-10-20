# action_view.cr

A Crystal port of Rails **ActionView 8.1.4** — ERB templates, layouts,
partials, the form builder and view helpers. Namespace `ActionView`
mirrors the original 1:1; templates keep ERB syntax and are compiled into
render methods at build time (via a `run()` template processor, like the
stdlib's ECR). `<%= %>` auto-escapes; a `SafeString` type marks safe HTML.
Parity is verified against the real gem with oracle specs (151 examples,
0 failures).

> ⚠️ EXPERIMENTAL FRAMEWORK, DO NOT USE IN PRODUCTION YET.

## Installation

```yaml
dependencies:
  action_view_cr:
    github: OrelSokolov/action_view.cr
```

```sh
shards install
```

Requires Crystal >= 1.21.0; pairs with `active_support.cr` and
`action_pack.cr` (routes/params).

## Usage

Templates are Rails-compatible ERB (`app/views/<controller>/<action>.html.erb`):

```erb
<%# app/views/posts/show.html.erb %>
<h1><%= @post.title %></h1>
<%= link_to "Edit", edit_post_path(@post) %>

<%= form_with model: @post do |f| %>
  <%= f.label :title %>
  <%= f.text_field :title %>
  <%= f.submit %>
<% end %>
```

```crystal
# The application declares partials and their local types at compile time:
compile_partials({
  "shared/post" => {post: Post},
})
```

## Feature comparison vs actionview 8.1.4

### Rendering

| Feature | Original (actionview) | Port (action_view.cr) | Status |
|---|---|---|---|
| ERB action templates + layouts (`yield`, nested layouts) | ✅ | Compile-time render methods; Rails 8.1 newline semantics (trailing `\n` chomp on action templates) | ✅ |
| `content_for` / `provide` / `content_for?`, `capture`, `concat` | ✅ | Same | ✅ |
| `render partial: "shared/post", locals: {...}`, collection render (`render @posts` → `_post.erb`, `<name>_counter`, `<name>_iteration`) | ✅ | Locals are real typed arguments of the compiled method; counter is 0-based (Rails 7.1+ behavior, oracle-confirmed) | 🔶 |
| Controller instance variables visible in views | ✅ | Same | ✅ |

### Form helpers

| Feature | Original | Port | Status |
|---|---|---|---|
| `form_with model: @post do \|f\|` (+ `url:`, `scope:`), `form_tag` + `*_tag` helpers | ✅ | Same, incl. CSRF authenticity token in non-GET forms (`authenticity_token: false` to disable) | ✅ |
| `FormBuilder`: `label, text_field, password_field, hidden_field, text_area, check_box, radio_button, submit`, `field_name` | ✅ | Same; models implement the `ActionView::FormModel` interface (`form_scope`/`form_attributes`/`form_persisted?`) | ✅ |
| `FormBuilder`: `file_field, select, collection_select, grouped_collection_select, collection_check_boxes/radio_buttons, typed fields (email/number/date/time/...), field_id, button` | ✅ | Not ported yet | ⬜ |
| Tag-level fields: `text/password/email/search/url/tel/date/color/number/range` + `file/time/datetime/datetime_local/month/week/phone` (`*_tag`), `image_submit_tag` | ✅ | Same, byte-exact (incl. `datetime` → `datetime-local` type, image src `/images/` asset prefix) | ✅ |
| `button_tag`/`label_tag` with block; `check_box_tag`/`radio_button_tag` `id: nil`, `disabled`, attribute order (opts before `checked`) | ✅ | Same (oracle-locked merge order) | ✅ |
| `fields_for` (view-level + `FormBuilder#fields_for`) | ✅ | Byte-identical nested names `user[posts_attributes][0][title]`, auto `hidden_field :id` after the block for persisted children, `child_index:`/`include_id:` | ✅ |
| Nested-attributes index naming (`post[comments_attributes][0][_destroy]`) | ✅ | Same | ✅ |

### Content, tags, text & numbers

| Feature | Original | Port | Status |
|---|---|---|---|
| Output safety (`html_safe`, `raw`, `safe_join`, `escape_once`) | ✅ | SafeString marker type | ✅ |
| `content_tag`, `tag("br")`, `tag.br` dot form | ✅ | Dot form is a fixed list of ~110 HTML elements, macro-generated | 🔶 |
| URL helpers: `link_to` (options/block), `link_to_if/unless`, `button_to`, `current_page?`, `mail_to/phone_to/sms_to` | ✅ | Same | ✅ |
| `url_for(model)` polymorphic URLs | ✅ | Not ported | ⬜ |
| Text: `pluralize, truncate, excerpt, highlight, word_wrap, simple_format, cycle/...` | ✅ | Same | ✅ |
| Numbers: `number_to_currency/delimiter/precision/human_size/human/percentage/phone` | ✅ | Same (locale data) | ✅ |
| `debug`, `distance_of_time_in_words`, `time_ago_in_words`, `t/l` (I18n) | ✅ | Same | ✅ |
| Asset helpers: `stylesheet_link_tag, javascript_include_tag, javascript_tag, image_tag, video_tag, audio_tag, favicon_link_tag, csrf_meta_tags, csp_meta_tag` | ✅ | Same; fingerprint manifest `public/assets/manifest.json` + `compute_asset_path` (Sprockets/Propshaft are not ported) | 🔶 |
| `sanitize, strip_tags, strip_links` | ✅ | Needs an HTML parser (lexbor) | ⬜ |
| Fragment cache: `cache`/`cache_if`/`cache_unless`/`fragment_cache_key` | ✅ | Explicit string keys, `ActionView.perform_caching`/`cache_store` (NullStore by default) | 🔶 |
| Russian-doll cache keys (template digest, dependency tracker), array/object keys | ✅ | Not ported | ⬜ |

### Vite integration (beyond actionview — ports vite_rails 3.0.19 / vite_ruby 3.9.2)

| Feature | Original (vite_rails) | Port | Status |
|---|---|---|---|
| `vite_javascript_tag` (ESM + modulepreload + CSS chunks), `vite_stylesheet_tag`, `vite_asset_path`, `vite_image_tag` | ✅ | Byte-identical output vs oracle; vite 5/6 manifest format | ✅ |
| Dev-server detection & dev tags (`vite_client_tag`, `vite_react_refresh_tag`) | ✅ | TCP probe (1 s cache), dev lookup without manifest; HTTP/ws proxy lives in railties | 🔶 |
| `config/vite.json`, custom tag options, `skip_proxy`/`auto_build` | ✅ | Not supported; `type:` is a String, not a Symbol | ❌ (equivalent: class-level `ViteRuby::Manifest` properties + env vars) |

## Deviations & Crystal-specific notes

- Locals are a Crystal literal: `locals: {"post" => post}` (a Ruby-style
  `{post: post}` is a NamedTuple in Crystal).
- Partial local types are declared by the application in `compile_partials`
  (compile-time framework; Crystal does not allow `Object` in generics).
- FormBuilder methods are a fixed set (in Rails they are also generated
  once by a CodeGenerator).
- Templates are scanned and compiled at build time (`CRAILS_VIEWS` or
  `app/views`).

## Testing

```sh
crystal spec
```

Oracle specs: `oracle/cases.rb` recorded against actionview 8.1.4 →
`oracle/expected.yml`; the Vite layer is recorded against real
vite_rails 3.0.19 / vite_ruby 3.9.2 (`oracle/vite_cases.rb`,
`oracle/vite_dev_cases.rb`). Suite: 151 examples, 0 failures.
