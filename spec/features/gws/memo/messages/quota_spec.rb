require 'spec_helper'

describe 'gws_memo_messages', type: :feature, dbscope: :example, js: true do
  let(:site) { gws_site }
  let(:quota_size) { rand(1..10) }
  let!(:sender) { create(:gws_user, cur_site: site, gws_role_ids: gws_user.gws_role_ids) }
  let!(:recipient) { create(:gws_user, cur_site: site, gws_role_ids: gws_user.gws_role_ids) }
  let(:subject) { "subject-#{unique_id}" }
  let(:text) { ("text-#{unique_id}\r\n" * 3).strip }

  before do
    login_user(sender)
    site.memo_quota = quota_size
    site.save!
  end

  context 'when total size is over quota' do
    before do
      msg = create(:gws_memo_message, cur_site: site, cur_user: gws_user, in_to_members: [recipient.id.to_s])
      msg.filtered[gws_user.id.to_s] = Time.zone.now
      msg.filtered[sender.id.to_s] = Time.zone.now
      msg.filtered[recipient.id.to_s] = Time.zone.now
      msg.save
      msg.set(size: quota_size * 1024 * 1024)
    end

    it do
      visit gws_memo_messages_path(site)
      click_on I18n.t('ss.links.new')

      within 'form#item-form' do
        within 'dl.see.to' do
          wait_cbox_open do
            click_on I18n.t('gws.organization_addresses')
          end
        end
      end
      wait_for_cbox do
        expect(page).to have_content(recipient.name)
        wait_cbox_close do
          click_on recipient.name
        end
      end

      within 'form#item-form' do
        fill_in 'item[subject]', with: subject
        fill_in 'item[text]', with: text

        page.accept_confirm do
          click_on I18n.t('ss.buttons.send')
        end
      end
      wait_for_error I18n.t('mongoid.errors.models.gws/memo/message.member_quota_over', member: recipient.long_name)
    end
  end

  context 'when total size reaches almost quota' do
    before do
      msg = create(:gws_memo_message, cur_site: site, cur_user: gws_user, in_to_members: [recipient.id.to_s])
      msg.filtered[gws_user.id.to_s] = Time.zone.now
      msg.filtered[sender.id.to_s] = Time.zone.now
      msg.filtered[recipient.id.to_s] = Time.zone.now
      msg.save
      msg.set(size: quota_size * 1024 * 1024 - 1)
    end

    it do
      visit gws_memo_messages_path(site)
      click_on I18n.t('ss.links.new')

      within 'form#item-form' do
        within 'dl.see.to' do
          click_on I18n.t('gws.organization_addresses')
        end
      end
      wait_for_cbox do
        expect(page).to have_content(recipient.name)
        click_on recipient.name
      end

      within 'form#item-form' do
        fill_in 'item[subject]', with: subject
        fill_in 'item[text]', with: text

        page.accept_confirm do
          click_on I18n.t('ss.buttons.send')
        end
      end
      expect(page).to have_css('#notice', text: I18n.t('ss.notice.sent'))
    end
  end
end
