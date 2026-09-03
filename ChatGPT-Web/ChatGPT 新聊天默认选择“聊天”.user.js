// ==UserScript==
// @name         ChatGPT 新聊天默认选择“聊天”
// @namespace    local.chatgpt.default-chat
// @version      1.0.0
// @description  每次新建 ChatGPT 对话时默认选择“聊天”，之后不干涉用户手动切换到“工作”
// @license      MIT
// @homepageURL  https://github.com/RongNianXin/codex-workflows/tree/main/ChatGPT-Web
// @supportURL   https://github.com/RongNianXin/codex-workflows/issues
// @updateURL    https://raw.githubusercontent.com/RongNianXin/codex-workflows/main/ChatGPT-Web/ChatGPT%20%E6%96%B0%E8%81%8A%E5%A4%A9%E9%BB%98%E8%AE%A4%E9%80%89%E6%8B%A9%E2%80%9C%E8%81%8A%E5%A4%A9%E2%80%9D.user.js
// @downloadURL  https://raw.githubusercontent.com/RongNianXin/codex-workflows/main/ChatGPT-Web/ChatGPT%20%E6%96%B0%E8%81%8A%E5%A4%A9%E9%BB%98%E8%AE%A4%E9%80%89%E6%8B%A9%E2%80%9C%E8%81%8A%E5%A4%A9%E2%80%9D.user.js
// @match        https://chatgpt.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    // ==============================
    // 配置
    // ==============================

    // ChatGPT 普通“新聊天”页面
    const NEW_CHAT_PATHS = new Set([
        '/',
        '/chat'
    ]);

    // 同时兼容中文和英文界面
    const CHAT_TEXTS = new Set([
        '聊天',
        'Chat'
    ]);

    const WORK_TEXTS = new Set([
        '工作',
        'Work'
    ]);

    // ==============================
    // 状态
    // ==============================

    // 当前这一次“新聊天”是否已经处理过
    let handled = false;

    // 记录当前路径
    let lastPath = location.pathname;

    // 防止 MutationObserver 过于频繁调用
    let attemptScheduled = false;


    // ==============================
    // 工具函数
    // ==============================

    function normalizeText(text) {
        return (text || '')
            .replace(/\s+/g, ' ')
            .trim();
    }


    function isVisible(element) {
        if (!element) return false;

        const rect = element.getBoundingClientRect();

        return (
            rect.width > 0 &&
            rect.height > 0 &&
            rect.bottom > 0 &&
            rect.right > 0 &&
            rect.top < window.innerHeight &&
            rect.left < window.innerWidth
        );
    }


    function isNewChatPage() {
        return NEW_CHAT_PATHS.has(location.pathname);
    }


    // ==============================
    // 找到顶部“聊天 / 工作”切换器
    // ==============================

    function findChatWorkToggle() {

        const selector = [
            'button',
            '[role="tab"]',
            '[role="radio"]',
            '[role="button"]',
            'span',
            'div'
        ].join(',');

        const allElements = Array.from(
            document.querySelectorAll(selector)
        );

        // 找所有文字正好为“聊天”或“Chat”的元素
        const chatElements = allElements.filter(element => {
            return (
                isVisible(element) &&
                CHAT_TEXTS.has(
                    normalizeText(element.textContent)
                )
            );
        });


        for (const chatElement of chatElements) {

            let container = chatElement;

            // 向上寻找几层父元素
            for (
                let level = 0;
                level < 6 && container;
                level++, container = container.parentElement
            ) {

                const rect = container.getBoundingClientRect();

                /*
                 * 我们只寻找：
                 *
                 * 1. 页面顶部区域
                 * 2. 尺寸比较小的控件
                 *
                 * 这样可以避免误点页面其他位置
                 * 出现的“聊天”文字。
                 */
                if (
                    rect.top >= 0 &&
                    rect.top < 180 &&
                    rect.width > 50 &&
                    rect.width < 400 &&
                    rect.height > 20 &&
                    rect.height < 140
                ) {

                    const descendants = Array.from(
                        container.querySelectorAll(selector)
                    );

                    const workElement = descendants.find(element => {

                        return (
                            isVisible(element) &&
                            WORK_TEXTS.has(
                                normalizeText(element.textContent)
                            )
                        );

                    });


                    // 同一个小区域中同时存在“聊天”和“工作”
                    // 才认为找到了真正的顶部模式开关
                    if (workElement) {

                        return {
                            chatElement,
                            workElement,
                            container
                        };

                    }
                }
            }
        }

        return null;
    }


    // ==============================
    // 点击“聊天”
    // ==============================

    function selectChatOnce() {

        // 已经执行过，就永远不再干预
        // 直到下一次真正进入“新聊天”
        if (handled) {
            return;
        }

        // 不是新聊天页面，不处理
        if (!isNewChatPage()) {
            return;
        }


        const toggle = findChatWorkToggle();

        // 页面可能还没有加载完成
        if (!toggle) {
            return;
        }


        /*
         * 非常重要：
         *
         * 在真正点击之前，就先标记为 handled。
         *
         * 这样即使点击“聊天”引起页面重新渲染，
         * MutationObserver 再次被触发，
         * 脚本也不会再点击第二次。
         */
        handled = true;


        const clickable =
            toggle.chatElement.closest(
                'button,[role="tab"],[role="radio"],[role="button"]'
            )
            ||
            toggle.chatElement;


        console.log(
            '[ChatGPT 默认聊天] 新聊天页面已选择“聊天”，本次不再干预。'
        );


        clickable.click();
    }


    // ==============================
    // 限流执行
    // ==============================

    function scheduleAttempt() {

        if (attemptScheduled || handled) {
            return;
        }

        if (!isNewChatPage()) {
            return;
        }


        attemptScheduled = true;


        setTimeout(() => {

            attemptScheduled = false;

            selectChatOnce();

        }, 80);
    }


    // ==============================
    // 监听页面变化
    // ==============================

    function handleRouteChange() {

        const currentPath = location.pathname;


        // 地址没有变化
        if (currentPath === lastPath) {
            return;
        }


        const previousPath = lastPath;

        lastPath = currentPath;


        /*
         * 从已有对话：
         *
         * /c/xxxxxxxx
         *
         * 回到：
         *
         * /
         *
         * 就意味着你点击了“新建聊天”。
         */
        if (isNewChatPage()) {

            handled = false;

            console.log(
                '[ChatGPT 默认聊天] 检测到新的聊天页面。'
            );

            scheduleAttempt();

        } else {

            // 已进入实际对话页面
            // 停止任何模式干预
            handled = true;
        }
    }


    // ==============================
    // 监听页面 DOM
    // ==============================

    function startObserver() {

        if (!document.documentElement) {

            setTimeout(startObserver, 50);

            return;
        }


        const observer = new MutationObserver(() => {

            handleRouteChange();

            scheduleAttempt();

        });


        observer.observe(
            document.documentElement,
            {
                childList: true,
                subtree: true
            }
        );


        // 第一次进入 ChatGPT 首页
        if (isNewChatPage()) {

            handled = false;

            scheduleAttempt();

        } else {

            handled = true;
        }
    }


    // ==============================
    // 监听浏览器前进 / 后退
    // ==============================

    window.addEventListener(
        'popstate',
        () => {

            setTimeout(() => {

                handleRouteChange();

                scheduleAttempt();

            }, 0);

        }
    );


    // ==============================
    // 监听 ChatGPT SPA 内部导航
    // ==============================

    ['pushState', 'replaceState'].forEach(methodName => {

        const original = history[methodName];


        history[methodName] = function (...args) {

            const result =
                original.apply(this, args);


            setTimeout(() => {

                handleRouteChange();

                scheduleAttempt();

            }, 0);


            return result;
        };

    });


    startObserver();

})();
