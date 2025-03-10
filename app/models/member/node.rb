module Member::Node
  class Base
    include Cms::Model::Node

    default_scope ->{ where(route: /^member\//) }
  end

  class Login
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Member::Addon::Redirection
    include Member::Addon::FormAuth
    include Member::Addon::TwitterOAuth
    include Member::Addon::FacebookOAuth
    include Member::Addon::YahooJpOAuth
    include Member::Addon::YahooJpOAuthV2
    include Member::Addon::GoogleOAuth
    include Member::Addon::GithubOAuth
    include Member::Addon::LineOAuth
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/login") }

    def redirect_full_url
      return if redirect_url.blank?

      ret = make_full_url(redirect_url)
      return if ret.blank?
      return unless trusted?(ret)

      ret.to_s
    end

    def make_trusted_full_url(ref)
      return if ref.blank?

      full_url = make_full_url(Addressable::URI.unencode(ref))
      return if full_url.blank?

      # normalize full url
      full_url.fragment = nil
      full_url.query = nil

      # trusted?
      return unless trusted?(full_url)

      full_url.to_s
    end

    private

    def make_full_url(path)
      site_root_url = URI.parse(site.full_root_url)
      URI.join(site_root_url, path) rescue nil
    end

    def trusted?(full_url)
      return false if full_url.blank?

      %w(http https).include?(full_url.scheme) && full_url.to_s.start_with?(site.full_url)
    end
  end

  class Mypage
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::Html
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/mypage") }

    def children
      Member::Node::Base.and_public.
        where(site_id: site_id, filename: /^#{::Regexp.escape(filename)}\//, depth: depth + 1).
        order_by(order: 1)
    end
  end

  class MyProfile
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Member::Addon::Registration::RequiredFields
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/my_profile") }
  end

  class Registration
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Member::Addon::Registration::Notice
    include Member::Addon::Registration::SenderAddress
    include Member::Addon::Registration::Confirmation
    include Member::Addon::Registration::Reply
    include Member::Addon::Registration::Completed
    include Member::Addon::Registration::ResetPassword
    include Member::Addon::Registration::RequiredFields
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/registration") }
  end

  class MyBlog
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Member::Addon::EditorSetting
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/my_blog") }

    def setting_url
      "#{url}setting/"
    end
  end

  class MyPhoto
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/my_photo") }
  end

  class Blog
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::NodeList
    include Member::Addon::Blog::BlogSetting
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    self.use_liquid = false

    default_scope ->{ where(route: "member/blog") }

    def sort_hash
      return { created: -1 } if sort.blank?
      super
    end

    def layout_options
      Member::BlogLayout.site(site).where(filename: /^#{::Regexp.escape(filename)}\//).
        map { |item| [item.name, item.id] }
    end
  end

  class BlogPage
    include Cms::Model::Node
    include Cms::Addon::MemberReference
    include Member::Addon::Blog::PageSetting
    include Cms::Addon::PageList
    include Cms::Addon::GroupPermission

    self.use_liquid = false

    set_permission_name "member_blogs"

    default_scope ->{ where(route: "member/blog_page") }

    before_validation ->{ self.page_layout = layout }

    def pages
      Member::BlogPage.site(site).where(filename: /^#{::Regexp.escape(filename)}\//, depth: depth + 1).and_public
    end

    def file_previewable?(file, site:, user:, member:)
      return true if super

      return true if member.present? && member_id == member.id

      false
    end
  end

  class BlogPageLocation
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::PageList
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    self.use_liquid = false

    default_scope ->{ where(route: "member/blog_page_location") }

    def sort_hash
      return { created: -1 } if sort.blank?
      super
    end

    def condition_hash(options = {})
      super(options.reverse_merge(category: :blog_page_location_ids))
    end
  end

  class Photo
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::PageList
    include Member::Addon::Photo::LicenseSetting
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/photo") }
  end

  class PhotoSearch
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Member::Addon::Photo::Search::PageList
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/photo_search") }

    def condition_hash(options = {})
      if conditions.present?
        # 指定されたフォルダー内のページが対象
        super
      else
        # サイト内の全ページが対象
        default_site = options[:site] || @cur_site || self.site
        { site_id: default_site.id }
      end
    end
  end

  class PhotoSpot
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::PageList
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/photo_spot") }
  end

  class PhotoCategory
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::PageList
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/photo_category") }

    def condition_hash(options = {})
      super(options.reverse_merge(category: :photo_category_ids))
    end
  end

  class PhotoLocation
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::PageList
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/photo_location") }

    def condition_hash(options = {})
      super(options.reverse_merge(category: :photo_location_ids))
    end
  end

  class MyAnpiPost
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Board::Addon::AnpiPostSetting
    include Board::Addon::GooglePersonFinderSetting
    include Board::Addon::MapSetting
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/my_anpi_post") }
  end

  class MyGroup
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Member::Addon::Registration::SenderAddress
    include Member::Addon::GroupInvitationSetting
    include Member::Addon::MemberInvitationSetting
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/my_group") }
  end

  class MyLineProfile
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Member::Addon::Registration::RequiredFields
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/my_line_profile") }
  end

  class LineFirstRegistration
    include Cms::Model::Node
    include Cms::Addon::NodeSetting
    include Cms::Addon::Meta
    include Cms::Addon::Release
    include Cms::Addon::GroupPermission
    include History::Addon::Backup

    default_scope ->{ where(route: "member/line_first_registration") }
  end
end
