module Gws::Memo::NoticeUserSetting
  extend ActiveSupport::Concern
  extend Gws::UserSetting

  MAX_MAIL_COUNT = SS.config.gws.dig("memo", "max_notice_mail_address_count") || 10

  included do
    %w(schedule todo report workflow circular monitor board faq qna survey discussion announcement affair).each do |name|
      field "notice_#{name}_user_setting", type: String, default: 'notify'
      field "notice_#{name}_email_user_setting", type: String, default: 'silence'
      permit_params "notice_#{name}_user_setting".to_sym
      permit_params "notice_#{name}_email_user_setting".to_sym

      alias_method("notice_#{name}_user_setting_options", "notice_user_setting_options")
      alias_method("notice_#{name}_email_user_setting_options", "notice_email_user_setting_options")
    end

    field :send_notice_mail_addresses, type: SS::Extensions::Words
    permit_params :send_notice_mail_addresses
    validates :send_notice_mail_addresses, emails: true, length: { maximum: MAX_MAIL_COUNT, message: :too_large }
  end

  def notice_user_setting_options
    %w(notify silence).map { |k| [I18n.t("ss.options.state.#{k}"), k] }
  end

  def notice_email_user_setting_options
    %w(notify silence).map { |k| [I18n.t("gws/memo/notice_user_settings.options.email.#{k}"), k] }
  end

  def notice_user_setting_default_value
    I18n.t("ss.options.state.notify")
  end

  def notice_email_user_setting_default_value
    I18n.t("ss.options.state.silence")
  end

  def use_notice?(model)
    function = model_convert_to_i18n_key(model)
    return false unless function
    try("notice_#{function}_user_setting") != "silence"
  end

  def use_notice_email?(model)
    function = model_convert_to_i18n_key(model)
    return false unless function
    try("notice_#{function}_email_user_setting") == "notify"
  end

  private

  def model_convert_to_i18n_key(model)
    case model.model_name.i18n_key.to_s
    when "gws/board/topic", "gws/board/post" then 'board'
    when "gws/circular/post" then 'circular'
    when "gws/faq/topic", "gws/faq/post" then 'faq'
    when "gws/qna/topic", "gws/qna/post" then 'qna'
    when "gws/schedule/todo", "gws/schedule/todo_comment" then 'todo'
    when "gws/schedule/plan", "gws/schedule/comment", "gws/schedule/attendance", "gws/schedule/approval" then 'schedule'
    when "gws/discussion/topic", "gws/discussion/post" then 'discussion'
    when "gws/workflow/file" then 'workflow'
    when "gws/report/file" then 'report'
    when "gws/notice/post" then 'announcement'
    when "gws/survey/form", "gws/survey/file" then 'survey'
    when "gws/monitor/topic", "gws/monitor/post" then 'monitor'
    when "gws/affair/overtime_file", "gws/affair/leave_file", "compensatory_file" then 'affair'
    end
  end
end
