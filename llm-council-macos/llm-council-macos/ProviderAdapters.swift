//
//  ProviderAdapters.swift
//  LLM Council
//
//

import Foundation

struct SelectorBasedProviderAdapter: ProviderAutomationAdapter {
    let providerID: ProviderID
    let inputSelectors: [String]
    let sendButtonSelectors: [String]

    func makeSendScript(prompt: String) -> String {
        JavaScriptBridgeBuilder.makeSendScript(
            prompt: prompt,
            inputSelectors: inputSelectors,
            sendButtonSelectors: sendButtonSelectors
        )
    }
}

enum ProviderAdapterRegistry {
    static let adapters: [ProviderID: any ProviderAutomationAdapter] = [
        .chatGPT: SelectorBasedProviderAdapter(
            providerID: .chatGPT,
            inputSelectors: [
                "#prompt-textarea",
                "textarea[data-id='root']",
                "textarea[placeholder*='Message']",
                "textarea",
                "[contenteditable='true']",
            ],
            sendButtonSelectors: [
                "button[data-testid='send-button']",
                "button[data-testid*='send']",
                "button[data-testid='fruitjuice-send-button']",
                "button[aria-label*='Send']",
                "button[aria-label*='send']",
                "button[type='submit']",
            ]
        ),
        .claude: SelectorBasedProviderAdapter(
            providerID: .claude,
            inputSelectors: [
                "div.ProseMirror",
                "[contenteditable='true']",
            ],
            sendButtonSelectors: [
                "button[aria-label='Send Message']",
                "button[aria-label*='Send']",
                "button[data-testid*='send']",
                "button[class*='send']",
                "button[type='submit']",
            ]
        ),
        .gemini: SelectorBasedProviderAdapter(
            providerID: .gemini,
            inputSelectors: [
                ".ql-editor[aria-label='Enter a prompt here']",
                ".ql-editor",
                "[contenteditable='true']",
                "textarea",
            ],
            sendButtonSelectors: [
                "button[aria-label='Send message']",
                "button[aria-label*='Send']",
                "button[class*='send']",
                "button[type='submit']",
            ]
        ),
        .grok: SelectorBasedProviderAdapter(
            providerID: .grok,
            inputSelectors: [
                "textarea[aria-label*='Ask']",
                "textarea[placeholder*='Ask']",
                "[contenteditable='true'][role='textbox']",
                "[contenteditable='true']",
                "textarea",
            ],
            sendButtonSelectors: [
                "button[aria-label='Submit']",
                "button[type='submit']",
                "button[aria-label*='Send']",
            ]
        ),
        .perplexity: SelectorBasedProviderAdapter(
            providerID: .perplexity,
            inputSelectors: [
                "textarea[placeholder*='Ask']",
                "textarea[placeholder*='Follow-up']",
                "textarea",
                "[contenteditable='true']",
            ],
            sendButtonSelectors: [
                "button[aria-label*='Submit']",
                "button[aria-label*='Send']",
                "button[type='submit']",
            ]
        ),
        .deepSeek: SelectorBasedProviderAdapter(
            providerID: .deepSeek,
            inputSelectors: [
                "textarea[placeholder*='Ask']",
                "textarea[placeholder*='问']",
                "textarea",
                "[contenteditable='true']",
            ],
            sendButtonSelectors: [
                "button[aria-label*='Submit']",
                "button[aria-label*='Send']",
                "button[type='submit']",
                "button[aria-label*='发送']",
            ]
        ),
    ]

    static func adapter(for providerID: ProviderID) -> (any ProviderAutomationAdapter)? {
        adapters[providerID]
    }
}

private enum JavaScriptBridgeBuilder {
    static func makeSendScript(
        prompt: String,
        inputSelectors: [String],
        sendButtonSelectors: [String]
    ) -> String {
        let promptLiteral = jsonLiteral(prompt)
        let inputSelectorsLiteral = jsonLiteral(inputSelectors)
        let sendButtonSelectorsLiteral = jsonLiteral(sendButtonSelectors)

        return """
        (async function() {
          const prompt = \(promptLiteral);
          const inputSelectors = \(inputSelectorsLiteral);
          const sendSelectors = \(sendButtonSelectorsLiteral);
          const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

          const findFirst = (selectors) => {
            for (const selector of selectors) {
              try {
                const node = document.querySelector(selector);
                if (node) return node;
              } catch (error) {}
            }
            return null;
          };

          const findSendButton = () => {
            for (const selector of sendSelectors) {
              try {
                const buttons = Array.from(document.querySelectorAll(selector));
                for (const button of buttons) {
                  const disabled = button.disabled
                    || button.getAttribute("aria-disabled") === "true"
                    || button.classList.contains("disabled");
                  const visible = button.getClientRects().length > 0;
                  if (!disabled && visible) {
                    return button;
                  }
                }
              } catch (error) {}
            }
            return null;
          };

          const setPromptValue = (input, value) => {
            const isTextInput = input.tagName === "TEXTAREA" || input.tagName === "INPUT";
            if (isTextInput) {
              const prototype = input.tagName === "TEXTAREA" ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
              const setter = Object.getOwnPropertyDescriptor(prototype, "value")?.set;
              if (setter) {
                setter.call(input, value);
              } else {
                input.value = value;
              }
              input.dispatchEvent(new Event("input", { bubbles: true }));
              input.dispatchEvent(new Event("change", { bubbles: true }));
              return;
            }

            input.focus();
            if (input.isContentEditable) {
              try {
                document.execCommand("selectAll", false);
                document.execCommand("insertText", false, value);
              } catch (error) {}
              if (!input.textContent || input.textContent.trim() !== String(value).trim()) {
                input.textContent = value;
              }
              input.dispatchEvent(new Event("input", { bubbles: true }));
              input.dispatchEvent(new Event("change", { bubbles: true }));
              return;
            }

            input.textContent = value;
          };

          const clickSend = () => {
            const button = findSendButton();
            if (button) {
              button.click();
              return true;
            }
            return false;
          };

          const input = findFirst(inputSelectors);
          if (!input) {
            return { ok: false, error: "input-not-found" };
          }

          input.click();
          input.focus();
          setPromptValue(input, prompt);

          // Wait briefly for React/Quill/ProseMirror state updates to enable send.
          for (let attempt = 0; attempt < 30; attempt += 1) {
            if (clickSend()) {
              return { ok: true, method: "button" };
            }
            await sleep(60);
          }

          // Fallback through form submission when available.
          const form = input.closest("form");
          if (form) {
            if (typeof form.requestSubmit === "function") {
              form.requestSubmit();
            } else if (typeof form.submit === "function") {
              form.submit();
            }
            return { ok: true, method: "form" };
          }

          // Last-resort key submission attempts.
          input.dispatchEvent(
            new KeyboardEvent("keydown", {
              key: "Enter",
              code: "Enter",
              which: 13,
              keyCode: 13,
              metaKey: true,
              bubbles: true,
              cancelable: true
            })
          );
          input.dispatchEvent(
            new KeyboardEvent("keyup", {
              key: "Enter",
              code: "Enter",
              which: 13,
              keyCode: 13,
              metaKey: true,
              bubbles: true,
              cancelable: true
            })
          );

          input.dispatchEvent(
            new KeyboardEvent("keydown", {
              key: "Enter",
              code: "Enter",
              which: 13,
              keyCode: 13,
              bubbles: true,
              cancelable: true
            })
          );
          input.dispatchEvent(
            new KeyboardEvent("keyup", {
              key: "Enter",
              code: "Enter",
              which: 13,
              keyCode: 13,
              bubbles: true,
              cancelable: true
            })
          );

          return { ok: false, error: "send-not-triggered" };
        })();
        """
    }

    private static func jsonLiteral<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(value),
            let encoded = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }
        return encoded
    }
}
