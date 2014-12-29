#!/bin/sh
# time: 2014/12/28 20:05:00
source /etc/profile >/dev/null

#设置从boafanx获取的服务器IP
ipmatch=63.141.248.218

#邮件提醒
email="xxxxxxx@qq.com"

#是否发送邮件 1 发送 0 不发送
isemail=0

logger "[boafanx shadownsocks] update started" 
#-----------------------------------------------------------------------------
#判断mutt
which mutt >/dev/null 2>&1
[ $? -eq 0 ] || isemail=0
#配置文件路径
File1=/etc/shadowsocks.json
#临时缓存文件
File2=/tmp/shadowsocks.json.tmp
File3=/tmp/shadowsocks.sh
TMPFILE=/tmp/curl.tmp
#循环2次 确定网络可用
for i in 1 2;do
        wget -O $TMPFILE http://boafanx.tabboa.com/boafanx-ss/
        [ $? -eq 0 ] && {
                for j in 1 2 3;do
                        wget -O $TMPFILE http://boafanx.tabboa.com/boafanx-ss/
                        [ $? -eq 0 ] && {
                                #获取指定服务器的配置信息
                                grep -A 6 -B 1 "$ipmatch" $TMPFILE | sed 's/<pre><code>//g' >$File2
                                #修改shadowsocks本地端口为65500
                                sed -i 's/"local_port":.*/"local_port":65500,/g' $File2

                                #简单判断是json格式
                                [ "`head -n 1 $File2 2>/dev/null`" = "{" -a "`tail -n 1 $File2 2>/dev/null`" = "}" ] && {
                                        CurRow=1 
                                        LastRow=`cat $File2 | wc -l`
                                        Eq=1
                                        [ -f $File1 ] || {
                                                touch $File1
                                                Eq=0
                                        }
                                        rm -f $TMPFILE
                                        #对比是否更新
                                        sed -i 's/    "/"/g' $File2
                                        sed -i '9,$d' $File2
                                        sed -i '4d' $File2
                                        while [ $CurRow -le $LastRow ];do
                                                file1Line="`awk 'NR=='$CurRow' {print $0}' $File1`"
                                                file2Line="`awk 'NR=='$CurRow' {print $0}' $File2`"
                                                echo "$CurRow/$LastRow $file1Line <=> $file2Line" >>$TMPFILE
                                                #逐行对比
                                                [  "$file1Line" = "$file2Line" ] || Eq=0
                                                CurRow=$((CurRow+1))
                                        done
                                        [ "$Eq" = "0" ] && {
                                                #cp -rf $File2 $File1
                                                #/etc/init.d/shadowsocks restart 1>/dev/null 2>&1
                                                sed -i '7d' $File2
                                                sed -i '1d' $File2
                                                sed -i 's/,//g' $File2
                                                sed -i 's/"server":/nvram set tow_ss_server=/g' $File2
                                                sed -i 's/"server_port":/nvram set tow_ss_server_port=/g' $File2
                                                sed -i 's/"local_port":/nvram set tow_ss_local_port=/g' $File2
                                                sed -i 's/"password":/nvram set tow_ss_passwd=/g' $File2
                                                sed -i 's/"timeout":/nvram set tow_ss_timeout=/g' $File2
                                                sed -i 's/"method":/nvram set tow_ss_crypt_method=/g' $File2
                                                mv $File2 $File3
                                                sh $File3
                                                nvram set tow_ss_local_port=65500
                                                nvram commit
                                                service tow restart
                                                logger "[boafanx shadownsocks] update success"
                                                #发送邮件提醒
                                                [ "$isemail" = "1" ] && mutt -s "[shadownsocks] Configuration file has been updated" $email <$TMPFILE
                                        }
                                        logger "[boafanx shadownsocks] don't need update"
                                        break
                                } || {
                                        logger "[boafanx shadownsocks] Contents does not match"
                                        [ "$isemail" = "1" ] && mutt -s "[boafanx shadownsocks] Contents does not match" $email <$File2
                                }
                                break
                        } || {
                                sleep 5
                                logger "[boafanx shadownsocks] Get content error"
                                [ $j -eq 3 -a "$isemail" = "1" ] && mutt -s "[boafanx shadownsocks] Get content error" $email <$TMPFILE
                        }
                done

                break
        } || {
                sleep 15
        }
done
rm -f $TMPFILE
rm -rf $File2
rm -rf $File3
