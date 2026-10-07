#include "NativeBridge.h"
#include <spawn.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
int32_t gm_command_spawn(const char *executable,const char *argument,const char *directory,const char *home) {
    if (!executable || !argument || !home || (strcmp(executable,"/bin/zsh") && strcmp(executable,"/usr/bin/shortcuts"))) return -1;
    posix_spawnattr_t attributes; posix_spawn_file_actions_t files;
    posix_spawnattr_init(&attributes); posix_spawn_file_actions_init(&files);
    posix_spawnattr_setflags(&attributes,POSIX_SPAWN_SETPGROUP); posix_spawnattr_setpgroup(&attributes,0);
    posix_spawn_file_actions_addopen(&files,0,"/dev/null",O_RDONLY,0);
    posix_spawn_file_actions_addopen(&files,1,"/dev/null",O_WRONLY,0);
    posix_spawn_file_actions_addopen(&files,2,"/dev/null",O_WRONLY,0);
    if (directory && directory[0]) posix_spawn_file_actions_addchdir_np(&files,directory);
    char homeValue[4096]; if (snprintf(homeValue,sizeof(homeValue),"HOME=%s",home)>=(int)sizeof(homeValue)) { posix_spawnattr_destroy(&attributes); posix_spawn_file_actions_destroy(&files); return -1; }
    char *args[]={(char*)executable,strcmp(executable,"/bin/zsh")==0 ? "-lc" : "run",(char*)argument,NULL};
    char *env[]={"PATH=/usr/bin:/bin:/usr/sbin:/sbin","LANG=en_US.UTF-8",homeValue,NULL};
    pid_t pid=0; int result=posix_spawn(&pid,executable,&files,&attributes,args,env);
    posix_spawnattr_destroy(&attributes); posix_spawn_file_actions_destroy(&files);
    return result==0 ? pid : -1;
}
int32_t gm_command_poll(int32_t pid,int32_t *status) {
    if (pid<=0 || !status) return -1;
    int raw=0; pid_t result=waitpid(pid,&raw,WNOHANG);
    if (result==0) return 0;
    if (result<0) return errno==EINTR ? 0 : -1;
    *status=WIFEXITED(raw) ? WEXITSTATUS(raw) : 128+(WIFSIGNALED(raw) ? WTERMSIG(raw) : 0); return 1;
}
void gm_command_cancel(int32_t pid,bool force) { if (pid>0) kill(-pid,force ? SIGKILL : SIGTERM); }
