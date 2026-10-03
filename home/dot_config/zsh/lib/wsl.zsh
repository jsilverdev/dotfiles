if command -v npiperelay.exe >/dev/null 2>&1; then
    export SSH_AUTH_SOCK="${HOME}/.ssh/agent.sock"

    ssh-add -l >/dev/null 2>&1
    agent_status=$?

    if [ $agent_status -gt 1 ]; then
        rm -f "${SSH_AUTH_SOCK}"
        ( setsid socat UNIX-LISTEN:"${SSH_AUTH_SOCK}",fork EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork & ) >/dev/null 2>&1
    fi

fi
