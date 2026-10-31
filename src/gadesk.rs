use base::config::keys;
use hbb_common::config;
use std::sync::Once;

const APP_NAME: &str = "GADESK";
const ID_SERVER: &str = "gadesk.grupoamayo.com";
const RELAY_SERVER: &str = "gadesk.grupoamayo.com:21117";
const PUBLIC_KEY: &str = include_str!("../res/gadesk/server-public-key.txt");

pub fn initialize() {
    static INITIALIZE: Once = Once::new();
    INITIALIZE.call_once(|| {
        *config::APP_NAME.write().unwrap() = APP_NAME.to_owned();
        *config::PROD_RENDEZVOUS_SERVER.write().unwrap() = ID_SERVER.to_owned();
        config::DEFAULT_SETTINGS.write().unwrap().extend([
            (keys::OPTION_CUSTOM_RENDEZVOUS_SERVER.to_owned(), ID_SERVER.to_owned()),
            (keys::OPTION_RELAY_SERVER.to_owned(), RELAY_SERVER.to_owned()),
            (keys::OPTION_KEY.to_owned(), PUBLIC_KEY.trim().to_owned()),
        ]);
        // The stock updater distributes upstream builds with a different identity.
        config::OVERWRITE_SETTINGS
            .write()
            .unwrap()
            .insert(keys::OPTION_ALLOW_AUTO_UPDATE.to_owned(), "N".to_owned());
        config::OVERWRITE_LOCAL_SETTINGS
            .write()
            .unwrap()
            .insert(keys::OPTION_ENABLE_CHECK_UPDATE.to_owned(), "N".to_owned());
    });
}
