class Rss::Page
  include Cms::Model::Page
  include Cms::Page::SequencedFilename
  include Rss::Addon::Page::Body
  include Category::Addon::Category
  include Cms::Addon::Release
  include Cms::Addon::GroupPermission
  include History::Addon::Backup

  set_permission_name "article_pages"

  index({ released: 1, id: 1 })

  store_in_repl_master
  default_scope ->{ where(route: "rss/page") }
end
