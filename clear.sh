#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

clean_system() {
    echo -e "${GREEN}开始系统自动清理...${RESET}"

    # 清理缓存与残留包
    if command -v apt &>/dev/null; then
        echo -e "${GREEN}检测到 APT 系统${RESET}"
        apt autoremove -y
        apt clean -y
        apt autoclean -y
        dpkg -l | awk '/^rc/ {print $2}' | xargs -r apt purge -y
        # 安全删除旧内核
        apt --purge autoremove -y
    elif command -v yum &>/dev/null; then
        echo -e "${GREEN}检测到 YUM 系统${RESET}"
        yum autoremove -y
        yum clean all
        if command -v package-cleanup &>/dev/null; then
            package-cleanup --oldkernels --count=2 -y
        fi
    elif command -v dnf &>/dev/null; then
        echo -e "${GREEN}检测到 DNF 系统${RESET}"
        dnf autoremove -y
        dnf clean all
        if command -v package-cleanup &>/dev/null; then
            package-cleanup --oldkernels --count=2 -y
        fi
    elif command -v apk &>/dev/null; then
        echo -e "${GREEN}检测到 APK 系统${RESET}"
        apk cache clean
        # APK 内核删除需手动操作或按包名删除旧内核
    else
        echo -e "${RED}暂不支持你的系统！${RESET}"
        exit 1
    fi

    # 清理日志（保留最近 7 天）
    echo -e "${GREEN}清理日志文件（保留最近 7 天）...${RESET}"
    journalctl --vacuum-time=7d

    echo -e "${GREEN}系统清理完成！${RESET}"
}

# 执行自动清理
clean_system
