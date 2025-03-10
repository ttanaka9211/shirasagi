this.Webmail_Mail_Navi = (function () {
  function Webmail_Mail_Navi() {
  }

  Webmail_Mail_Navi.render = function () {
    $('.webmail-navi-mailboxes .reload').on("click", function () {
      return Webmail_Mail_Navi.reloadMailbox();
    });
    $('.webmail-navi-quota .reload').on("click", function () {
      return Webmail_Mail_Navi.reloadQuota();
    });
    return $(".webmail-select-account").on("change", function () {
      return location.href = $(this).val();
    });
  };

  Webmail_Mail_Navi.reloadMailbox = function (opts) {
    var btn, navi;
    if (opts == null) {
      opts = {};
    }
    navi = $('.webmail-navi-mailboxes');
    btn = navi.find('.reload');
    if (btn.hasClass('disabled')) {
      return false;
    }
    $.ajax({
      url: btn.attr('href'),
      beforeSend: function () {
        btn.addClass('disabled');
        return navi.find('.unseen').remove();
      },
      success: function (data) {
        var h, i, mailbox, ref;
        ref = data.mailboxes;
        for (i in ref) {
          mailbox = ref[i];
          h = " <span class='unseen count" + mailbox.unseen + "'>(" + mailbox.unseen + ")</span>";
          navi.find("a[data-name='" + mailbox.original_name + "']").append(h);
        }
        if (data.notice && opts['notice'] !== -1) {
          SS.notice(data.notice);
        }
        var uidnext = navi.find("a[data-name='INBOX']").data("uidnext")
        if (uidnext != data.inbox.uidnext) {
          if (location.pathname === data.inbox.url) {
            location.href = data.inbox.url;
          }
        }
        return btn.removeClass('disabled');
      }
    });
    return false;
  };

  Webmail_Mail_Navi.reloadQuota = function () {
    var al, btn, navi;
    navi = $('.webmail-navi-quota');
    btn = navi.find('.reload');
    al = $(".webmail-quota-alert");
    if (btn.hasClass('disabled')) {
      return false;
    }
    $.ajax({
      url: btn.attr('href'),
      beforeSend: function () {
        btn.addClass('disabled');
        navi.find('.label').html('--/--');
        return navi.find('.usage').css('width', 0);
      },
      success: function (data) {
        navi.find('.label').html(data.label);
        navi.find('.usage').css('width', data.percentage + '%');
        btn.removeClass('disabled');
        if (data.over_threshold) {
          navi.find('.usage').addClass("over-threshold");
          al.text(data.threshold_label);
          return al.show();
        } else {
          navi.find('.usage').removeClass("over-threshold");
          return al.hide();
        }
      }
    });
    return false;
  };

  return Webmail_Mail_Navi;

})();

this.Webmail_Mail_List = (function () {
  function Webmail_Mail_List() {
  }

  Webmail_Mail_List.render = function () {
    this.renderListStars();
    $(".list-head .search").on("click", function () {
      return $('.webmail-mail-search').animate({
        height: 'toggle'
      }, 'fast');
    });
    $(".webmail-mail-search .reset").on("click", function () {
      $(".webmail-mail-search input[type=text]").val("");
      $(".webmail-mail-search input[type=checkbox]").prop('checked', false);
      return $(".webmail-mail-search .search").trigger("click");
    });
    $(".list-head .move-all, .list-head .copy-all").each(function () {
      var menu, url;
      url = $(this).data('href');
      menu = $("#webmail-mailboxes-list .dropdown-menu").clone();
      menu.find("a").on("click", function () {
        var uids;
        uids = Webmail_Mail_List.findCheckedUids();
        if (uids.length === 0) {
          return false;
        }
        $('.dropdown-menu').removeClass('active');
        return Webmail_Mail_List.updateMails(url, {
          ids: uids,
          dst: $(this).data('name')
        });
      });
      return $(this).after(menu);
    });
    $(".list-head .update-all").on("click", function () {
      var uids;
      uids = Webmail_Mail_List.findCheckedUids();
      if (uids.length === 0) {
        return false;
      }
      $('.dropdown-menu').removeClass('active');
      $.ajax({
        url: $(this).attr('href'),
        method: 'POST',
        dataType: 'json',
        data: {
          _method: 'put',
          authenticity_token: $('meta[name="csrf-token"]').attr('content'),
          ids: uids
        },
        success: function (data) {
          Webmail_Mail_List.renderListFlags(uids, data.action);
          return SS.notice(data.notice);
        }
      });
      return false;
    });
    $(".list-head .delete-all").on("click", function () {
      if (!confirm(i18next.t("webmail.confirm.empty_mailbox"))) {
        return false;
      }
      $('.dropdown-menu').removeClass('active');
      $.ajax({
        url: $(this).attr('href'),
        method: 'POST',
        dataType: 'json',
        data: {
          _method: 'delete',
          authenticity_token: $('meta[name="csrf-token"]').attr('content')
        },
        success: function (data) {
          $('.webmail-mails .list-item').remove();
          $('.pagination').remove();
          return SS.notice(data.notice);
        }
      });
      return false;
    });
    $(".list-head .set-seen-all, .list-head .unset-seen-all").on("click", function () {
      var uids;
      uids = Webmail_Mail_List.findCheckedUids();
      if (uids.length === 0) {
        return false;
      }
      $('.dropdown-menu').removeClass('active');
      $.ajax({
        url: $(this).data('href'),
        method: 'POST',
        dataType: 'json',
        data: {
          _method: 'put',
          authenticity_token: $('meta[name="csrf-token"]').attr('content'),
          ids: uids
        },
        success: function (data) {
          Webmail_Mail_List.renderListFlags(uids, data.action);
          return SS.notice(data.notice);
        }
      });
      return false;
    });
    return this.renderDropEvents();
  };

  Webmail_Mail_List.findCheckedUids = function () {
    var checked;
    checked = $('.webmail-mails .list-item input:checkbox:checked').map(function () {
      return $(this).val();
    });
    return checked.get();
  };

  Webmail_Mail_List.findListItems = function (uids) {
    var items;
    if (uids == null) {
      uids = [];
    }
    return items = $('.webmail-mails .list-item').map(function () {
      var uid;
      uid = $(this).data('uid');
      if ($.inArray(uid + "", uids) === -1) {
        return null;
      }
      return $(this);
    });
  };

  Webmail_Mail_List.renderListFlags = function (uids, action) {
    var items;
    items = Webmail_Mail_List.findListItems(uids);
    switch (action) {
      case 'set_star':
        items.each(function () {
          return $(this).find('.icon-star').removeClass('off').addClass('on');
        });
        break;
      case 'unset_star':
        items.each(function () {
          return $(this).find('.icon-star').removeClass('on').addClass('off');
        });
        break;
      case 'set_seen':
        Webmail_Mail_Navi.reloadMailbox({ notice: -1 });
        items.each(function () {
          return $(this).removeClass('unseen').addClass('seen');
        });
        break;
      case 'unset_seen':
        Webmail_Mail_Navi.reloadMailbox({ notice: -1 });
        items.each(function () {
          return $(this).removeClass('seen').addClass('unseen');
        });
    }
    return false;
  };

  Webmail_Mail_List.renderListStars = function () {
    return $(".icon-star a").on("click", function () {
      var url, wrap;
      wrap = $(this).parent();
      if (wrap.hasClass('on')) {
        url = $(this).attr('href') + '/unset_star';
      } else {
        url = $(this).attr('href') + '/set_star';
      }
      $.ajax({
        url: url,
        method: 'POST',
        dataType: 'json',
        data: {
          _method: 'put'
        },
        success: function (data) {
          if (data.action === 'set_star') {
            wrap.removeClass('off').addClass('on');
          } else {
            wrap.removeClass('on').addClass('off');
          }
          if (data.notice) {
            SS.notice(data.notice);
          }
        }
      });
      return false;
    });
  };

  Webmail_Mail_List.renderDropEvents = function () {
    $('.webmail-mails.list-items .mail-draggable').draggable({
      revert: "invalid",
      revertDuration: 50,
      zIndex: 110,
      opacity: 0.5,
      cursor: "pointer",
      helper: function () {
        var ul;
        $(".tap-menu").hide();
        if (!$(this).find('[type="checkbox"]').prop('checked')) {
          $('.webmail-mails.list-items .mail-draggable').find('[type="checkbox"]').prop('checked', false);
          $(this).find('[type="checkbox"]').prop('checked', true);
        }
        ul = $('<ul></ul>');
        $('.webmail-mails.list-items .mail-draggable').each(function () {
          var cln, input;
          input = $(this).find('[type="checkbox"]');
          if (input.prop('checked') && $(ul).find("li").length < 4) {
            cln = $(this).clone();
            cln.find('[type="checkbox"]').prop('checked', true);
            cln.removeClass("mail-draggable");
            return ul.append(cln);
          }
        });
        return ul;
      }
    });
    $('.webmail-navi-mailboxes .mailbox-draggable').draggable({
      revert: "invalid",
      revertDuration: 50,
      zIndex: 110,
      opacity: 0.5,
      cursor: "pointer",
      start: function (e, ui) {
        return $(".tap-menu").hide();
      }
    });
    return $(".webmail-navi-mailboxes .mailbox-droppable").droppable({
      accept: ".mail-draggable,.mailbox-draggable",
      hoverClass: "droppable-hover",
      tolerance: "pointer",
      drop: function (e, ui) {
        var dst, ele, src, uids, url;
        $(".webmail-navi-mailboxes .mailbox-droppable").on("click.dragging", function () {
          return false;
        });
        ele = e.target;
        if (ui.draggable.hasClass("mail-draggable")) {
          dst = $(ele).attr("data-name");
          uids = [];
          $('.webmail-mails.list-items .mail-draggable').each(function () {
            var input;
            input = $(this).find('[type="checkbox"]');
            if (input.prop('checked')) {
              uids.push($(this).attr("data-uid"));
              return $(this).hide();
            }
          });
          url = $(".webmail-mails-head .move-all").attr("data-href");
          return Webmail_Mail_List.updateMails(url, {
            ids: uids,
            dst: dst
          });
        } else {
          src = ui.draggable.attr("data-name");
          dst = $(ele).attr("data-name") + "." + ui.draggable.attr("data-basename");
          url = $(".webmail-mails-head .rename-mailbox").attr("data-href");
          $(ui.draggable).hide();
          return Webmail_Mail_List.updateMailbox(url, {
            src: src,
            dst: dst
          });
        }
      }
    });
  };

  Webmail_Mail_List.updateMails = function (url, opts) {
    var form, id, j, len, ref, token;
    if (opts == null) {
      opts = {};
    }
    token = $('meta[name="csrf-token"]').attr('content');
    form = $("<form/>", {
      action: url,
      method: "post"
    });
    form.append($("<input/>", {
      type: "hidden",
      name: "_method",
      value: "put"
    }));
    form.append($("<input/>", {
      type: "hidden",
      name: "authenticity_token",
      value: token
    }));
    if (opts['redirect']) {
      form.append($("<input/>", {
        type: "hidden",
        name: "redirect",
        value: opts['redirect']
      }));
    }
    if (opts['dst']) {
      form.append($("<input/>", {
        type: "hidden",
        name: "dst",
        value: opts['dst']
      }));
    }
    if (opts['ids']) {
      ref = opts['ids'];
      for (j = 0, len = ref.length; j < len; j++) {
        id = ref[j];
        form.append($("<input/>", {
          name: "ids[]",
          value: id,
          type: "hidden"
        }));
      }
    }
    form.appendTo(document.body).submit();
    return false;
  };

  Webmail_Mail_List.updateMailbox = function (url, opts) {
    var form, token;
    if (opts == null) {
      opts = {};
    }
    token = $('meta[name="csrf-token"]').attr('content');
    form = $("<form/>", {
      action: url,
      method: "post"
    });
    form.append($("<input/>", {
      type: "hidden",
      name: "_method",
      value: "put"
    }));
    form.append($("<input/>", {
      type: "hidden",
      name: "authenticity_token",
      value: token
    }));
    if (opts['redirect']) {
      form.append($("<input/>", {
        type: "hidden",
        name: "redirect",
        value: opts['redirect']
      }));
    }
    if (opts['src']) {
      form.append($("<input/>", {
        type: "hidden",
        name: "src",
        value: opts['src']
      }));
    }
    if (opts['dst']) {
      form.append($("<input/>", {
        type: "hidden",
        name: "dst",
        value: opts['dst']
      }));
    }
    form.appendTo(document.body).submit();
    return false;
  };

  return Webmail_Mail_List;

})();

this.Webmail_Mail_Detail = (function () {
  function Webmail_Mail_Detail() {
  }

  Webmail_Mail_Detail.render = function () {
    Webmail_Mail_Detail.htmlMessage = new SS_HtmlMessage('.webmail-mail .body--html');
    $(".update-mail").on("click", function () {
      $('.dropdown-menu').removeClass('active');
      $.ajax({
        url: $(this).attr('href'),
        method: 'POST',
        dataType: 'json',
        data: {
          _method: 'put',
          authenticity_token: $('meta[name="csrf-token"]').attr('content')
        },
        success: function (data) {
          if (data.action === 'set_star') {
            $('.icon-star').removeClass('off').addClass('on');
          } else if (data.action === 'unset_star') {
            $('.icon-star').removeClass('on').addClass('off');
          }
          return SS.notice(data.notice);
        }
      });
      return false;
    });
    return $(".send-mdn,.ignore-mdn").on("click", function () {
      if ($(this).hasClass('disabled')) {
        return false;
      }
      return $.ajax({
        url: $(this).attr("href"),
        method: 'POST',
        dataType: 'json',
        data: {
          _method: 'put',
          authenticity_token: $('meta[name="csrf-token"]').attr('content')
        },
        beforeSend: function () {
          return $(".send-mdn,.ignore-mdn").addClass('disabled');
        },
        success: function (data) {
          SS.notice(data.notice);
          return $(".request-mdn-notice").remove();
        }
      });
    });
  };

  Webmail_Mail_Detail.loadImages = function () {
    return $("img[data-url]").each(function () {
      var url;
      url = $(this).data('url');
      if (url.match(/^parts\//)) {
        url = location.pathname + "/" + url;
      }
      $(this).attr('src', url);
      $(this).css('height', 'auto');
      return $(this).removeAttr('data-url');
    });
  };

  return Webmail_Mail_Detail;

})();

this.Webmail_Mail_Address = (function () {
  function Webmail_Mail_Address() {
  }

  Webmail_Mail_Address.render = function (opts) {
    var lang, urls;
    lang = opts.lang;
    urls = opts.urls;
    return $('.address-item').each(function () {
      var addr, email, menu, name;
      addr = $(this);
      addr.addClass('clickable');
      name = addr.data('name');
      email = addr.data('email');
      menu = addr.find('.dropdown-menu');
      if (!email) {
        addr.removeClass('dropdown');
        menu.remove();
        return true;
      }
      addr.find('.address-name').prepend('<i class="material-icons md-14">&#xE7FD;</i>');
      menu.append('<li class="dropdown-menu-item disabled">' + email + '</li>');
      menu.append('<li><a href="#" class="addr-send ss-open-in-new-window">' + lang.send + '</a></li>');
      menu.append('<li><a href="#" class="addr-entry">' + lang.entry + '</a></li>');
      menu.append('<li><a href="#" class="addr-copy">' + lang.copy + '</a></li>');
      $(this).find('.addr-send').each(function () {
        var href = urls.send + "?" + $.param({
          item: {
            to: name + "<" + email + ">"
          }
        });
        this.setAttribute('href', href);
      });
      $(this).find('.addr-entry').on("click", function () {
        location.href = urls.add + "?" + $.param({
          item: {
            name: name,
            email: email
          }
        });
        return false;
      });
      return $(this).find('.addr-copy').on("click", function () {
        SS_Clipboard.copy(email);
        $(".dropdown, .dropdown-menu").removeClass('active');
        return false;
      });
    });
  };

  return Webmail_Mail_Address;

})();

this.Webmail_Mail_Form = (function () {
  function Webmail_Mail_Form() {
  }

  Webmail_Mail_Form.render = function () {
    $('.js-autosize').autosize();
    $('.cc-bcc-label').on("click", function () {
      $('.webmail-mail-form-address.cc-bcc').animate({
        height: 'toggle'
      }, 'fast');
      return false;
    });
    $('#item_format').on("change", function () {
      return Webmail_Mail_Form.renderBodyForm($(this).val());
    });
    Webmail_Mail_Form.renderBodyForm($('#item_format').val());
    $('#item_signature').on("change", function () {
      if ($(this).val() === "") {
        return;
      }
      if ($('#item_format').val() === "html") {
        CKEDITOR.instances['item_html'].insertText($(this).val());
      } else {
        Webmail_Mail_Form.insertText($("#item_text"), $(this).val());
      }
      return $(this).val("");
    });
    $('.js-send').on("click", function () {
      if (!$('input[name="item[to][]"][value!=""]').length) {
        return $('#item_to_text').attr('required', true);
      } else {
        return $('#item_to_text').attr('required', false);
      }
    });
    return $('.js-save').on("click", function () {
      return $('#item_to_text').attr('required', false);
    });
  };

  Webmail_Mail_Form.renderBodyForm = function (format) {
    if (format === 'html') {
      $('.body-text').hide();
      return $('.body-html').show();
    } else {
      $('.body-html').hide();
      return $('.body-text').show();
    }
  };

  Webmail_Mail_Form.insertText = function (field, str) {
    var np, p, r, s;
    field.focus();
    if (navigator.userAgent.match(/MSIE/)) {
      r = document.selection.createRange();
      r.text = str;
      return r.select();
    } else {
      s = field.val();
      p = field.get(0).selectionStart;
      np = p + str.length;
      field.val(s.substr(0, p) + str + s.substr(p));
      return field.get(0).setSelectionRange(np, np);
    }
  };

  return Webmail_Mail_Form;

})();

this.Webmail_Mail_Form_Address = (function () {
  function Webmail_Mail_Form_Address() {
  }

  Webmail_Mail_Form_Address.select = function (item) {
    var data, dl, field, label, selected, self, span, value;
    self = this;
    data = item.closest("[data-id]");
    dl = self.anchorAjaxBox.closest(".webmail-mail-form-address");
    field = $(dl).find(".autocomplete");
    label = data.data("email");
    value = data.data("address");
    selected = dl.find(".selected-address");
    if (label === "") {
      return;
    }
    span = Webmail_Address_Autocomplete.createSelectedElement(field.attr("data-name"), value, label);
    return selected.append(span);
  };

  return Webmail_Mail_Form_Address;

})();

