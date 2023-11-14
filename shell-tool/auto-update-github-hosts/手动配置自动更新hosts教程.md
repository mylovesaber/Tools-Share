# �ֶ��̳�

�ҵ�һ���ű������ڴ�ͳ linux ��������ƻ�����µ� MacOS ϵͳ�����ƫ��ϵͳ���԰������½������н������ӵĿ��Լӣ�·����ϵͳ��������ʱ����������ʱ��֪��Ϊʲôϵͳ��������Ĳ������·������ sh ���� bash ���������䣬һ���ű������������������ε�·������������룬�ܽ�������Ҷ��Ҳ���뷢�� issue �������������ܣ��ڴ˱�ʾ��л��(setup.sh �еĴ����Ѿ����������ˣ�hosts-tool.sh �еĴ���������ںܶ�ë��)

## ��Ҫ�������

������������ȫ���˽���У�

- ����ϵͳˢ�� DNS �Ĳ�����������������ο���ͨ��������ʵ�� DNS ��ˢ�£�
- ��ˢ�� DNS �������Ч�� hosts ���ļ�·��
- cron ��ʱ������Ч�ľ��岽��

����������ˢ�� padavan ��С��·�������������Ѳ��Կ��õ� openwrt ϵͳΪ��

## 1. ���� hosts �ļ�
### 1.1 ���� hosts �ļ�
��������������°� hosts �ļ�����Ϊ /etcĿ¼�µ� newhosts �ļ���

```bash
curl https://raw.hellogithub.com/hosts > /etc/newhosts
```

### 1.2 ɾ��ԭ�� hosts �ļ��еĹ�ʱ hosts ��Ϣ

���� Linux/Unix �µ� hosts �ļ�λ�ö���: `/etc/hosts`������padavan��openwrt ��·����ϵͳ����һ��������Ч��·��: `/etc/storage/dnsmasq/hosts`�������ĸ�·����Ч���Բ⣬���� `/etc/hosts` ��Ч����ô�ȱ���һ�£�

```bash
cp -a /etc/hosts /etc/hosts.bak
```

Ȼ��ɾ�� `/etc/hosts` �����еĹ�ʱ hosts ��Ϣ��

```bash
sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' /etc/hosts
```

Ȼ���������� `cat /etc/hosts` ����ɾ����ʱ��Ϣ��� hosts �ļ��Ƿ���ʾ���������������ִ�к�������������ָ�����: `cp -af /etc/hosts.bak /etc/hosts`

**��Ҫ�ر�С�ĵ�һ���ǣ�һ��Ҫֱ�Ӹ����Լ����ص��� hosts �еĹؼ��ʣ�����ܴ���ʻ��������µ����⣺**

����������������ƥ����ı���Ӧ���кţ����ܿ��ó����� `# Github520 Host End` ��ʲô��������һ��ƥ�䲻����Ӧ�к�������û����������������������ģ����� sed ��ɾ�����ܶ��ԣ�һ����һ���ı���Ϣƥ�����˾ͻῪ��ɾ�����ܣ���ƥ�䲻����ȷ���ı���Ϣ�Թر�ɾ�����ܵĻ������� hosts �ļ��еĹ��򶼻ᱻɾ���ɾ����������ע��

```bash
root@VM-12-16-centos ~ # awk '/# Github520 Host End/{print NR}' hosts
root@VM-12-16-centos ~ # awk '/# GitHub520 Host End/{print NR}' hosts
43
root@VM-12-16-centos ~ #
```

�����������ӵ�һ�е�ƥ������Ϣ����ֱ�Ӹ��Ƶ���ҳ�����ѷ����������²���ʱ������ hosts ȫɾ�ɾ��ˡ�������

```bash
0 6 * * * sed -i '/# GitHub520 Host Start/,/# Github520 Host End/d' /etc/storage/dnsmasq/hosts;wget --no-check-certificate https://raw.hellogithub.com/hosts -O /etc/storage/dnsmasq/hosts.bak;cat /etc/storage/dnsmasq/hosts.bak >> /etc/storage/dnsmasq/hosts;restart_dhcpd
```

���������������Ļ������Ժ��ҽű��еĲ���һ����Ϊ���ϸ��µ� hosts ���������еĹ�����Ե�������һ�������ļ���Ȼ�����ƴ�ӣ����ո��ǵ�ԭ�� hosts �ļ����У��������԰ٷְٹ���������ɾ������ë����

### 1.3 �����°� hosts ����

һ���㶨��

```bash
cat /etc/newhosts >> /etc/hosts
```

## 2. ˢ�� DNS ����

ֱ���滻 hosts �ļ��Ļ�����ʱ����� DNS ���浼���� hosts �����޷���ʱ��Ч����֪·���������������������ʵ��Ŀ�ģ�

```bash
restart_dhcpd
restart_dns
```

��ͬϵͳ����ͬϵͳ���п��ܳ�����һ��ˢ��������Ч������һ��û��Ч�������⣬�������Բ�

## 3. ��ʱ����

����ÿ 1 Сʱ����һ����Ϊ test ���ļ�����ʽ��
```bash
echo "* */1 * * * test" | crontab -
```

# �Զ�����

���ַ�ʽѡһ�־��У���Ϊ ssh �� root ��ݵ�¼·�����նˣ������Լ�����ʵ�ʿ��õ�����ı����еĲ������ã��������ַ���ʹ�� sed ��������ע�⿪���͹ر�ɾ����������Ӧƥ����ı������� ok �����ã���
�� padavan ��������֪�������£�
- /etc/hosts �ļ�ֱ���޸���Ч
- ˢ�� DNS �������Ч����Ϊ: `restart_dns`

## һ����ʱ

```bash
echo "* */1 * * * sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' /etc/hosts; curl https://raw.hellogithub.com/hosts >> /etc/hosts; sed -i '/^</d' /etc/hosts; restart_dns" | crontab - 
```

## ��ʱ�ű�

�������ƺ�ֱ��ճ���������У�ÿ������֮�����һ�У���������������һ���������ͬʱ���У���

```bash
cat < EOF > /etc/autoupdatehosts
#!/bin/bash
sed -i '/# GitHub520 Host Start/,/# GitHub520 Host End/d' /etc/hosts
curl https://raw.hellogithub.com/hosts >> /etc/hosts
sed -i '/^</d' /etc/hosts
restart_dns
EOF

chmod +x /etc/autoupdatehosts

echo "* */1 * * * /etc/autoupdatehosts" | crontab -
```