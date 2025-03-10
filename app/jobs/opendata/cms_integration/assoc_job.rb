class Opendata::CmsIntegration::AssocJob < Cms::ApplicationJob
  def perform(site_id, node_id, page_id, action)
    return unless self.site.dataset_enabled?
    @dataset_node = Opendata::Node::Dataset.site(self.site).first
    return if @dataset_node.blank?

    @cms_site = Cms::Site.find(site_id)
    @cms_node = Cms::Node.site(@cms_site).find(node_id)
    @cur_page = Cms::Page.site(@cms_site).node(@cms_node).find(page_id)

    @file_goes_to = []

    case action.to_sym
    when :create_or_update
      if @cur_page.opendata_dataset_state.present? && @cur_page.opendata_dataset_state != 'none'
        create_or_update_associated_dataset
      else
        close_associated_dataset
      end
    when :destroy
      close_associated_dataset
    end

    true
  end

  private

  def close_associated_dataset
    Opendata::Dataset.site(self.site).node(@dataset_node).and_resource_associated_page(@cur_page).each do |dataset|
      dataset.resources.and_associated_page(@cur_page).each do |resource|
        if resource.assoc_method != 'auto'
          Rails.logger.info("#{resource.name}: auto association is disabled in #{dataset.name}")
          next
        end

        resource.destroy
        Rails.logger.info("#{resource.name}: resource is destroyed")
      end
      dataset.save!
    end

    dataset = Opendata::Dataset.site(self.site).node(@dataset_node).and_associated_page(@cur_page).first
    # page isn't associated with dataset
    return if dataset.blank?
    # dataset is alread closed
    return if dataset.state == 'closed'
    return if dataset.resources.present?
    # auto association is disabled
    if dataset.assoc_method != 'auto'
      Rails.logger.info("#{dataset.name}: auto association is disabled")
      return
    end

    dataset.state = 'closed'
    dataset.save!
    Rails.logger.info("#{dataset.name}: dataset is closed")
  end

  def create_or_update_associated_dataset
    page_html = get_page_html
    if page_html.blank?
      Rails.logger.warn("#{@cur_page.name}: html is blank")
      #return # support for form page
    end

    files = @cur_page.attached_files
    if files.blank?
      Rails.logger.warn("#{@cur_page.name}: no files are attached")
      return
    end

    dataset = get_associated_dataset
    # auto association is disabled
    if dataset.present?
      if dataset.assoc_method == 'auto'
        update_dataset_by_page(dataset)
      else
        Rails.logger.info("#{dataset.name}: auto association is disabled")
      end
    end

    files.each do |file|
      state = @cur_page.opendata_resources_state(file)
      case state
      when 'none'
        # nothing to do with this file
        next
      when 'same'
        dataset ||= create_associated_dataset
        create_or_update_resource(dataset, file)
      when 'existance'
        ds = @cur_page.opendata_resources_datasets(file).site(self.site).first
        if ds.present?
          create_or_update_resource(ds, file)
        end
      end
    end

    destroy_all_resources_unassociated_with_page
  end

  def get_page_html
    if @cur_page.class.include?(Cms::Addon::Form::Page) && @cur_page.form
      ""
    elsif @cur_page.body_layout.present?
      @page_html ||= @cur_page.body_parts.join.to_s
    else
      @page_html ||= @cur_page.html.to_s
    end
  end

  def get_associated_dataset
    dataset = @cur_page.opendata_datasets.site(self.site).first if @cur_page.opendata_dataset_state == 'existance'
    dataset ||= Opendata::Dataset.site(self.site).node(@dataset_node).and_associated_page(@cur_page).first
    dataset
  end

  def create_associated_dataset
    attributes = {
      cur_site: self.site,
      cur_node: @dataset_node,
      name: @cur_page.name,
      text: convert_to_text(get_page_html),
      category_ids: find_category_ids(@cur_page),
      area_ids: find_area_ids(@cur_page),
      dataset_group_ids: find_dataset_group_ids(@cur_page),
      group_ids: @dataset_node.group_ids,
      assoc_site_id: @cms_site.id,
      assoc_node_id: @cms_node.id,
      assoc_page_id: @cur_page.id,
      assoc_site_ids: [@cms_site.id],
      assoc_node_ids: [@cms_node.id],
      assoc_page_ids: [@cur_page.id],
      state: @cur_page.opendata_dataset_state.presence == 'public' ? 'public' : 'closed'
    }
    if @cur_page.try(:contact_group_id)
      contact_group = Cms::Group.all.site(@dataset_node.site).where(id: @cur_page.contact_group_id).first
    end
    if @cur_page.try(:contact_group_contact_id) && contact_group
      contact = contact_group.contact_groups.where(id: @cur_page.contact_group_contact_id).first
    end
    attributes[:contact_state] = @cur_page.contact_state if @cur_page.respond_to?(:contact_state)
    attributes[:contact_group_id] = contact_group.try(:id)
    attributes[:contact_group_contact_id] = contact.try(:id)
    attributes[:contact_group_relation] = @cur_page.contact_group_relation if @cur_page.respond_to?(:contact_group_relation)
    attributes[:contact_charge] = @cur_page.contact_charge if @cur_page.respond_to?(:contact_charge)
    attributes[:contact_tel] = @cur_page.contact_tel if @cur_page.respond_to?(:contact_tel)
    attributes[:contact_fax] = @cur_page.contact_fax if @cur_page.respond_to?(:contact_fax)
    attributes[:contact_email] = @cur_page.contact_email if @cur_page.respond_to?(:contact_email)
    attributes[:contact_link_url] = @cur_page.contact_link_url if @cur_page.respond_to?(:contact_link_url)
    attributes[:contact_link_name] = @cur_page.contact_link_name if @cur_page.respond_to?(:contact_link_name)

    dataset = Opendata::Dataset.create(attributes)
    Rails.logger.info("#{dataset.name}: dataset is created")
    dataset
  end

  def update_dataset_by_page(dataset)
    dataset.name = @cur_page.name if @cur_page.opendata_dataset_state.presence != 'existance'
    dataset.text = convert_to_text(get_page_html) if @cur_page.opendata_dataset_state.presence != 'existance'
    dataset.category_ids = find_category_ids(@cur_page) if @cur_page.opendata_dataset_state.presence != 'existance'
    dataset.area_ids = find_area_ids(@cur_page) if @cur_page.opendata_dataset_state.presence != 'existance'
    dataset.dataset_group_ids = find_dataset_group_ids(@cur_page) if @cur_page.opendata_dataset_state.presence != 'existance'
    dataset.assoc_site_id = @cms_site.id
    dataset.assoc_node_id = @cms_node.id
    dataset.assoc_page_id = @cur_page.id
    dataset.assoc_site_ids = (dataset.resources.distinct(:assoc_site_id) << @cms_site.id).compact.uniq.sort
    dataset.assoc_node_ids = (dataset.resources.distinct(:assoc_node_id) << @cms_node.id).compact.uniq.sort
    dataset.assoc_page_ids = (dataset.resources.distinct(:assoc_page_id) << @cur_page.id).compact.uniq.sort
    dataset.state = @cur_page.opendata_dataset_state if %w(public closed).include?(@cur_page.opendata_dataset_state)

    # https://jira.mongodb.org/browse/MONGOID-4544
    # dataset.touch

    dataset.save!
  end

  def create_or_update_resource(dataset, file)
    resources = dataset.resources.and_associated_file(file)
    resources.blank? ? create_resource(dataset, file) : update_resources(dataset, resources, file)
  end

  def create_resource(dataset, file)
    license_id = find_license(file).id
    text = @cur_page.opendata_resources_text(file)

    resource = dataset.resources.new
    resource.associate_resource_with_file!(@cur_page, file, license_id, text)

    @file_goes_to << [ file.filename, dataset.id, resource.id ]
    Rails.logger.info("#{file.name}: resource is created in #{dataset.name}")
  end

  def update_resources(dataset, resources, file)
    license_id = find_license(file).id
    text = @cur_page.opendata_resources_text(file)

    resources.each do |resource|
      if resource.assoc_method != 'auto'
        Rails.logger.info("#{resource.name}: auto association is disabled in #{dataset.name}")
        next
      end

      resource.update_resource_with_file!(@cur_page, file, license_id, text)

      @file_goes_to << [ file.filename, dataset.id, resource.id ]
      Rails.logger.info("#{file.name}: resource is updated in #{dataset.name}")
    end
  end

  def destroy_all_resources_unassociated_with_page
    Opendata::Dataset.site(self.site).node(@dataset_node).and_resource_associated_page(@cur_page).each do |dataset|
      dataset.resources.and_associated_page(@cur_page).each do |resource|
        if resource.assoc_method != 'auto'
          Rails.logger.info("#{resource.name}: auto association is disabled in #{dataset.name}")
          next
        end

        unless resource_is_updated?(dataset, resource)
          resource.destroy
          Rails.logger.info("#{resource.name}: resource is destroyed")
          next
        end
      end

      dataset.state = 'closed' if dataset.resources.blank?

      def dataset.compression_dataset; end
      dataset.save!
      dataset.remove_file
      dataset
    end
  end

  def resource_is_updated?(dataset, resource)
    filename = resource.assoc_filename
    @file_goes_to.find do |fname, ds_id, rs_id|
      fname == filename && ds_id == dataset.id && rs_id == resource.id
    end
  end

  def find_category_ids(page)
    page.opendata_categories.site(self.site).and_public.pluck(:id)
  end

  def find_area_ids(page)
    page.opendata_areas.site(self.site).and_public.pluck(:id)
  end

  def find_dataset_group_ids(page)
    page.opendata_dataset_groups.site(self.site).and_public.pluck(:id)
  end

  def find_license(file)
    license = @cur_page.opendata_resources_licenses(file).site(self.site).and_public.order_by(order: 1, id: 1).first
    license ||= @cur_page.opendata_licenses.site(self.site).and_public.order_by(order: 1, id: 1).first
    criteria = Opendata::License.site(self.site).and_public
    license ||= criteria.and_default.order_by(order: 1, id: 1).first
    license ||= criteria.order_by(order: 1, id: 1).first
    license
  end

  def convert_to_text(html)
    html = html.dup
    html.gsub!(/<br.*?>/, "\n")
    html.gsub!(/<.+?>/, '')
    html = CGI.unescapeHTML(html)
    html.gsub!(/&nbsp;/, ' ')
    html
  end
end
