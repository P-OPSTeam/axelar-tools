notifiers:
  - name: telegram-channel
    type: telegram
    uid: telegram
    org_id: 1
    is_default: true
    send_reminder: false
    frequency: 5m
    disable_resolve_message: false
    # See `Supported Settings` section for settings supported for each
    # alert notification type.
    settings:
      chatid: 'TGCHATID'
      uploadImage: false
    # Secure settings that will be encrypted in the database (supported since Grafana v7.2). See `Supported Settings` section for secure settings supported for each notifier.
    secure_settings:
      bottoken: 'TGBOTTOKEN'