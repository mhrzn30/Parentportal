import { LightningElement } from "lwc";
import startSession from "@salesforce/apex/FamilyAssistantAgentController.startSession";
import sendMessageApex from "@salesforce/apex/FamilyAssistantAgentController.sendMessage";
import endSession from "@salesforce/apex/FamilyAssistantAgentController.endSession";

const STARTER_QUESTIONS = [
  "How do I apply?",
  "How does the lottery work?",
  "What documents do I need?",
  "How do I add another child?",
  "How do I contact Family Support?"
];

const FALLBACK_MESSAGE =
  "I'm having trouble connecting right now. Please try again in a moment, or contact Family Support at families@example.com / (555) 010-1000 (Region A) or regionb@example.com / (555) 010-2000 (Region B).";

export default class FamilyAssistantChat extends LightningElement {
  isOpen = false;
  isLoading = false;
  draftMessage = "";
  hasStarted = false;
  messages = [];

  sessionId;
  nextSequenceId = 1;

  get starterQuestions() {
    return STARTER_QUESTIONS;
  }

  get panelLabel() {
    return this.isOpen ? "Close Family Assistant" : "Open Family Assistant";
  }

  get hasMessages() {
    return this.messages.length > 0;
  }

  get inputClass() {
    return `ppc-chat__input ${this.draftMessage ? "" : "ppc-chat__input--empty"}`;
  }

  disconnectedCallback() {
    if (this.sessionId) {
      endSession({ sessionId: this.sessionId }).catch(() => {});
      this.sessionId = undefined;
    }
  }

  handleToggle() {
    this.isOpen = !this.isOpen;
    if (this.isOpen && !this.hasStarted) {
      this.hasStarted = true;
      this.isLoading = true;
      this.ensureSession().finally(() => {
        this.isLoading = false;
      });
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.isOpen = false;
      return;
    }

    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.sendMessage();
    }
  }

  handleInput(event) {
    this.draftMessage = event.target.value;
  }

  handleSubmit(event) {
    event.preventDefault();
    this.sendMessage();
  }

  handleStarterQuestion(event) {
    this.draftMessage = event.currentTarget.dataset.question;
    this.sendMessage();
  }

  async ensureSession() {
    if (this.sessionId) {
      return true;
    }

    try {
      const result = await startSession();
      this.sessionId = result.sessionId;
      this.appendAssistantReplies(result.replies);
      return true;
    } catch (error) {
      this.appendAssistantReplies([FALLBACK_MESSAGE]);
      return false;
    }
  }

  async sendMessage() {
    const message = this.draftMessage.trim();
    if (!message || this.isLoading) {
      return;
    }

    this.draftMessage = "";
    this.appendMessage(message, true);
    this.isLoading = true;

    try {
      const sessionReady = await this.ensureSession();
      if (!sessionReady) {
        return;
      }

      const sequenceId = this.nextSequenceId;
      this.nextSequenceId += 1;

      const result = await sendMessageApex({
        sessionId: this.sessionId,
        sequenceId,
        message
      });
      this.appendAssistantReplies(result.replies);
    } catch {
      this.appendAssistantReplies([FALLBACK_MESSAGE]);
    } finally {
      this.isLoading = false;
    }
  }

  appendAssistantReplies(replies) {
    if (!replies || replies.length === 0) {
      return;
    }
    replies.forEach((reply) => this.appendMessage(reply, false));
  }

  appendMessage(text, isUser) {
    this.messages = [
      ...this.messages,
      {
        id: `${isUser ? "user" : "assistant"}-${Date.now()}-${Math.random()}`,
        text,
        isUser,
        cssClass: `ppc-chat__message ppc-chat__message--${isUser ? "user" : "assistant"}`
      }
    ];
  }
}
