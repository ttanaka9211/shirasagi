module Gws::Addon::Schedule::Repeat
  extend ActiveSupport::Concern
  extend SS::Addon

  included do
    attr_accessor :repeat_type, :interval, :repeat_start, :repeat_end, :repeat_base, :wdays, :edit_range
    attr_accessor :todo_action

    belongs_to :repeat_plan, class_name: "Gws::Schedule::RepeatPlan"
    permit_params :repeat_type, :interval, :repeat_start, :repeat_end, :repeat_base, :edit_range, wdays: []

    validates :start_at, presence: true, if: -> { !repeat? }
    validates :end_at, presence: true, if: -> { !repeat? }
    validate :validate_repeat_params, if: -> { repeat? }
    validate :validate_repeat_plan, if: -> { repeat? }
    validate :validate_repeat_plan_max_date, if: -> { repeat? }

    before_save :save_repeat_plan, if: -> { repeat? }
    before_save :remove_repeat_plan, if: -> { repeat_type == '' }
    before_save :todo_action_repeat_plan, if: -> { todo_action.present? && edit_range }
    after_save :extract_repeat_plans, if: -> { repeat? }
    after_save :do_soft_or_undo_delete_with_repeat_plans, if: -> { deleted_changed? }
    before_destroy :remove_repeat_plan, if: -> { repeat_plan }
  end

  # 繰り返し予定を作成しているか。
  def repeat?
    repeat_type.present?
  end

  # repleat_plan が持つ値をコピーする。
  # 同期後にplanを更新するとrepeat_planの更新処理も実行する。
  def sync_repeat_plan
    if rp = repeat_plan || Gws::Schedule::RepeatPlan.new
      repeat_plan_fields.each { |name| self.send "#{name}=", rp.send(name) }
    end
  end

  def repeat_type_options
    [:daily, :weekly, :monthly, :yearly].map do |name|
      [I18n.t("gws/schedule.options.repeat_type.#{name}"), name.to_s]
    end
  end

  def repeat_base_options
    [:date, :wday].map do |name|
      [I18n.t("gws/schedule.options.repeat_base.#{name}"), name.to_s]
    end
  end

  def interval_options
    1..10
  end

  def extract_repeat_plans
    repeat_plan.extract_plans(self, cur_site, cur_user)
  end

  def destroy_without_repeat_plan
    @skip_remove_repeat_plan = true
    destroy
  end

  def todo_action_without_repeat_plan(action)
    @skip_todo_action_repeat_plan = true
    case action
    when 'disable'
      disable
    when 'finish'
      update(todo_state: 'finished')
    when 'revert'
      update(todo_state: 'unfinished')
    end
  end

  private

  def repeat_plan_fields
    [:repeat_type, :interval, :repeat_start, :repeat_end, :repeat_base, :wdays]
  end

  def validate_repeat_params
    self.repeat_start = start_at.to_date if repeat_start.blank? && start_at
  end

  def validate_repeat_plan
    @repeat_plan = repeat_plan || Gws::Schedule::RepeatPlan.new
    repeat_plan_fields.each { |name| @repeat_plan.send "#{name}=", send(name) }
    return if @repeat_plan.valid?

    @repeat_plan.errors.to_hash.each do |key, messages|
      messages.each { |m| errors.add key, m }
    end
  end

  def validate_repeat_plan_max_date
    site = @cur_site || self.site
    return unless site
    return unless site.schedule_max_at

    max  = site.schedule_max_at.in_time_zone + 1.day
    disp = I18n.l(site.schedule_max_at, format: :long)

    if repeat_start && repeat_start >= max
      errors.add :repeat_start, I18n.t('gws/schedule.errors.less_than_max_date', date: disp)
    elsif repeat_end && repeat_end >= max
      errors.add :repeat_end, I18n.t('gws/schedule.errors.less_than_max_date', date: disp)
    end
  end

  def save_repeat_plan
    # @extract_repeat_plans = nil
    return unless @repeat_plan.changed?

    # @extract_repeat_plans = true
    @repeat_plan.save
    self.repeat_plan_id = @repeat_plan.id
  end

  def remove_repeat_plan
    return if @skip_remove_repeat_plan

    if edit_range == "all" || repeat_type == ''
      remove_all_repeat_plan
    elsif edit_range == "later"
      remove_later_repeat_plan
    end

    if repeat_plan && self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id).empty?
      repeat_plan.destroy
      remove_attribute(:repeat_plan_id)
    end
  end

  def remove_all_repeat_plan
    return unless repeat_plan
    plans = self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id)
    plans.each do |plan|
      plan.skip_gws_history
      plan.destroy_without_repeat_plan
    end
  end

  def remove_later_repeat_plan
    return unless repeat_plan
    plans = self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id).gte(start_at: start_at)
    plans.each do |plan|
      plan.skip_gws_history
      plan.destroy_without_repeat_plan
    end
  end

  def todo_action_repeat_plan
    return if @skip_todo_action_repeat_plan

    if edit_range == "all" || repeat_type == ''
      todo_action_all_repeat_plan
    elsif edit_range == "later"
      todo_action_later_repeat_plan
    end

    if repeat_plan && self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id).empty?
      repeat_plan.destroy
      remove_attribute(:repeat_plan_id)
    end
  end

  def todo_action_all_repeat_plan
    return unless repeat_plan
    plans = self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id).active
    plans.each do |plan|
      plan.skip_gws_history
      plan.todo_action_without_repeat_plan(todo_action)
    end
  end

  def todo_action_later_repeat_plan
    return unless repeat_plan
    plans = self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id).gte(start_at: start_at).active
    plans.each do |plan|
      plan.skip_gws_history
      plan.todo_action_without_repeat_plan(todo_action)
    end
  end

  def do_soft_or_undo_delete_with_repeat_plans
    return unless repeat_plan

    if edit_range == 'all'
      plans = self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id)
    elsif edit_range == 'later'
      plans = self.class.where(repeat_plan_id: repeat_plan_id, :_id.ne => id).gte(start_at: start_at)
    else
      return
    end

    if deleted.present?
      plans = plans.without_deleted
    else
      plans = plans.only_deleted
    end

    plans.each do |plan|
      plan.cur_site = @cur_site
      plan.cur_user = @cur_user
      plan.skip_gws_history
      plan.deleted = self.deleted
      SS::Model.copy_errors(plan, self) if !plan.save
    end
  end
end
