local CWNGSync = require("frontend/plugins/cwngsync.koplugin/main")

function CWNGSync:onDispatcherRegisterActions()
    Dispatcher:registerAction("cwngsync_sync_now", { category="none", event="CWNGSyncSyncNow", title=_("Sync with CWNG now"), general=true,})
    Dispatcher:registerAction("cwngsync_push_progress", { category="none", event="CWNGSyncPushProgress", title=_("Push progress from this device to CWNG"), reader=true,})
    Dispatcher:registerAction("cwngsync_pull_progress", { category="none", event="CWNGSyncPullProgress", title=_("Pull progress from other devices to CWNG"), reader=true, separator=true,})
end
