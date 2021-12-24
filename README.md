# GVM Installer

Supported / tested on disro:

* Ubuntu 20+

Script install GVM 21 from scratch:

* Install dependences
* Download sources from official repo
* Build GVM and install
* Download NVT and others data

# Create cron update script
For updating GVM SecInfo database, script generate script:
```
/etc/cron.daily/sync_gvm.sh
```

# Usage

Download / Clone repo:

```
git clone https://github.com/m0zgen/install-gvm21.git
```

`cd` to repo folder and run ans select needed GVM version 20 or 21 in clean installed Ubuntu:

```
./install.sh
```

# Known issues

* GSAD service can be long started on firs time, after install script show notice about this issue.

# Additional docs
* https://github.com/greenbone/gvmd/blob/main/INSTALL.md#set-the-feed-import-owner
* https://greenbone.github.io/docs/gvm-21.04/index.html#setting-up-an-admin-user

