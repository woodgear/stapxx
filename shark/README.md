# kubeshark
## what it is
提供无侵入性的用户态程序可观测性
## what could i do to use it
### openresty
1. 火焰图  
    给定给定想要观测的nginx的pod selector,和在pod内的nginx的master的pod
    在给定的时间后(默认30s)返回这些nginx的所有process的火焰图
### ipvs
net yet
### api-server
net yet
### etcd
not yet
## any who use client-go
not yet

## how it work
大部分是systemtap，基于kong/stapxx(openresty/stapxx)
## is that safe
!!!! NO,IS NOT.IT MAY CRASH YOU HOST(unlike ebpf) !!!!
and we will try our best to avoid it.
## how to install/use
1. install chart
2. kubectl create ngshark
## i want take a quick shot
./kube-shark-demo.sh,wait 30s and open any flamegraph in ./fg via broswer.
it will
    1. create a kind name as kubeshark
    2. deploy a nginx echo server deployment name as nginx in defualt ns
    3. deploy a k6 pod in default ns,and keep bench the nginx pod
    3. install kubeshark in this kind
    4. create a ngshark cr
    5. wait 30s, and try to get flamegraph  in ngshark cr status put them in the fg dir in curdir.
## could i use it without k8s
yes. this usecase should be support.  
in standalone mode. we will embedded a k8s(api-server) in it,and provoid a restful api interface.
## i want use it as a datasource to promotheus/jagger/skywalking
yes. this usecase should be support.