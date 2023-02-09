# **uafedistats.sh**

Даний проєкт є форком [usercount](https://git.io/fNxgb), але переписаний з Python на Bash і використовує виключно список українських інстансів.

## **Залежності**

* `bash`
* `jq`
* `curl`
* `coreutils`
* `gnuplot`

## **Налаштування**
```
$ git clone https://github.com/uanet-exception/uafedistats.git /opt/uafedistats && cd /opt/uafedistats
...
/opt/uafedistats$ cp main.cfg.example main.cfg
/opt/uafedistats$ vim main.cfg
...
/opt/uafedistats$ echo "*/20  *    * * *   root    bash -c '/opt/uafedistats/uafedistats.sh update &>> /opt/uafedistats/errors.log'" | sudo tee -a /etc/crontab
/opt/uafedistats$ echo "0  *    * * *   root    bash -c '/opt/uafedistats/uafedistats.sh post &>> /opt/uafedistats/errors.log'" | sudo tee -a /etc/crontab
/opt/uafedistats$ sudo service cron reload
```