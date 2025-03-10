class Cms::Page
  include Cms::Model::Page
  include Cms::Addon::EditLock
  include Workflow::Addon::Branch
  include Workflow::Addon::Approver
  include Cms::Addon::Meta
  include Cms::Addon::TwitterPoster
  include Cms::Addon::LinePoster
  include Gravatar::Addon::Gravatar
  include Cms::Addon::Thumb
  include Cms::Addon::RedirectLink
  include Cms::Addon::Body
  include Cms::Addon::BodyPart
  include Cms::Addon::File
  include Cms::Addon::Form::Page
  include Category::Addon::Category
  include Cms::Addon::ParentCrumb
  include Event::Addon::Date
  include Map::Addon::Page
  include Cms::Addon::RelatedPage
  include Contact::Addon::Page
  include Cms::Addon::Tag
  include Cms::Addon::Release
  include Cms::Addon::ReleasePlan
  include Cms::Addon::GroupPermission
  include History::Addon::Backup
  include Cms::Addon::ForMemberPage

  index({ site_id: 1, filename: 1 }, { unique: true })

  # and_public
  #index({ site_id: 1, state: 1 })

  # public_list
  index({ filename: 1, depth: 1 })
  index({ category_ids: 1 })
  index({ group_ids: 1 })
  #index({ _id: 1, site_id: 1, state: 1 }, { unique: true })

  # rss
  index({ released: 1, id: 1 })

  after_save :new_size_input, if: ->{ @db_changes }

  class << self
    def routes
      pages = ::Mongoid.models.select { |model| model.ancestors.include?(Cms::Model::Page) }
      routes = pages.map { |model| model.name.underscore }.sort.uniq
      routes.map do |route|
        mod = route.sub(/\/.*/, '')
        { route: route, module: mod, module_name: I18n.t("modules.#{mod}"), name: I18n.t("mongoid.models.#{route}") }
      end
    end
  end
end
