// Bot Service - Wrapper around Socket SDK for bot subscriptions and chat functionality
import { SocketSDK } from '@99xio/xians-sdk-typescript';
import { MessageType } from '@99xio/xians-sdk-typescript';
import type { Message, EventHandlers } from '@99xio/xians-sdk-typescript';
import { getSDKConfig } from '../config/sdk';
import type { Bot, ChatMessage } from '../types';

export interface BotServiceOptions {
  onMessageReceived?: (message: ChatMessage) => void;
  onConnectionStateChanged?: (connected: boolean) => void;
  onError?: (error: string) => void;
  onDataMessageReceived?: (message: Message) => void;
  onChatRequestSent?: (requestId: string) => void;
  onChatResponseReceived?: (requestId: string) => void;
  participantId?: string;
  documentId?: string;
}

export class BotService {
  private socketSDK: SocketSDK;
  private currentAgent: Bot | null = null;
  private options: BotServiceOptions;
  private messageCounter = 0;
  private isLoadingHistory = false;
  private processedHistoryHashes = new Set<string>();
  private historyLoadedForAgent: string | null = null;

  // Expose current agent for external checks (read-only)
  getCurrentAgent(): Bot | null {
    return this.currentAgent;
  }

  // Update document ID for the service (used when navigating between documents)
  updateDocumentId(documentId?: string): void {
    const previousDocumentId = this.options.documentId;
    console.log(`[BotService] 🔧 UPDATEID: Updating document ID from "${previousDocumentId}" to "${documentId}"`);
    console.log(`[BotService] 🔧 UPDATEID: Comparison result - equal: ${previousDocumentId === documentId}, type prev: ${typeof previousDocumentId}, type new: ${typeof documentId}`);
    
    // Always update the document ID
    this.options.documentId = documentId;
    
    // Only reset state if document actually changed
    if (previousDocumentId !== documentId) {
      console.log(`[BotService] 🔧 UPDATEID: Document changed - forcing complete state reset`);
      
      // Complete state reset for document changes (mimics page refresh behavior)
      this.historyLoadedForAgent = null;
      this.processedHistoryHashes.clear();
      this.isLoadingHistory = false;
      
      console.log(`[BotService] 🔧 UPDATEID: State reset complete - historyLoadedForAgent: ${this.historyLoadedForAgent}`);
    } else {
      console.log(`[BotService] 🔧 UPDATEID: Document ID unchanged, skipping reset`);
    }
  }

  constructor(options: BotServiceOptions = {}) {
    this.options = options;
    
    const config = getSDKConfig();
    
    const eventHandlers: EventHandlers = {
      onReceiveChat: this.handleChatMessage.bind(this),
      onReceiveData: this.handleDataMessage.bind(this),
      onReceiveHandoff: this.handleHandoffMessage.bind(this),
      onThreadHistory: this.handleThreadHistory.bind(this),
      onConnected: this.handleConnected.bind(this),
      onDisconnected: this.handleDisconnected.bind(this),
      onConnectionError: this.handleConnectionError.bind(this),
      onError: this.handleError.bind(this),
    };

    this.socketSDK = new SocketSDK({
      tenantId: config.tenantId,
      apiKey: config.apiKey,
      serverUrl: config.serverUrl,
      autoReconnect: true,
      reconnectDelay: 3000,
      maxReconnectAttempts: 5,
      eventHandlers,
      logger: (message: string) => console.log(`[BotService] ${message}`),
    });
  }

  async connect(): Promise<void> {
    console.log('[BotService] Attempting to connect...');
    await this.socketSDK.connect();
    
    // Manually check connection state since onConnected might not be called
    setTimeout(() => {
      const isConnected = this.socketSDK.isConnected();
      console.log('[BotService] Manual connection check:', isConnected);
      if (isConnected) {
        this.handleConnected();
      }
    }, 1000); // Give it a moment to establish connection
  }

  async disconnect(): Promise<void> {
    await this.socketSDK.disconnect();
  }

  isConnected(): boolean {
    return this.socketSDK.isConnected();
  }

  async setCurrentAgent(agent: Bot): Promise<void> {
    const isAgentChange = !this.currentAgent || this.currentAgent.bot !== agent.bot;
    const isDocumentChange = this.historyLoadedForAgent === null; // This is set to null when updateDocumentId is called
    
    console.log(`[BotService] 🔧 SETAGENT: Agent setup check - currentAgent: ${this.currentAgent?.name}, newAgent: ${agent.name}`);
    console.log(`[BotService] 🔧 SETAGENT: Change detection - isAgentChange: ${isAgentChange}, isDocumentChange: ${isDocumentChange}, historyLoadedForAgent: ${this.historyLoadedForAgent}`);
    
    // Skip setup only if it's the same agent AND no document change
    if (this.currentAgent && this.currentAgent.bot === agent.bot && !isDocumentChange) {
      console.log(`[BotService] 🔧 SETAGENT: SKIPPING - Agent ${agent.name} already set with same document context`);
      return;
    }

    // Log the reason for the setup
    if (isAgentChange) {
      console.log(`[BotService] Agent change detected: ${this.currentAgent?.name} -> ${agent.name}`);
    } else if (isDocumentChange) {
      console.log(`[BotService] Document change detected for agent: ${agent.name}`);
    }

    // For document changes with same agent, force a complete reset to ensure clean state
    if (!isAgentChange && isDocumentChange) {
      console.log(`[BotService] 🔄 Forcing complete reset for document change`);
      
      // Temporarily unsubscribe and resubscribe to force fresh state
      if (this.currentAgent && this.isConnected()) {
        console.log(`[BotService] Temporarily unsubscribing for document change reset`);
        await this.socketSDK.unsubscribeFromAgent(
          this.currentAgent.bot,
          this.getParticipantId()
        );
      }
    }

    // Unsubscribe from previous agent if it's a different agent
    if (this.currentAgent && this.isConnected() && isAgentChange) {
      console.log(`[BotService] Unsubscribing from previous agent: ${this.currentAgent.name}`);
      await this.socketSDK.unsubscribeFromAgent(
        this.currentAgent.bot,
        this.getParticipantId()
      );
    }

    console.log(`[BotService] Setting current agent to: ${agent.name}`);
    
    // Clear processed history when switching agents or documents to allow fresh history loading
    this.processedHistoryHashes.clear();
    this.historyLoadedForAgent = null; // Reset to allow loading for new agent/document
    this.isLoadingHistory = false; // Reset loading state
    this.currentAgent = agent;

    // Always subscribe/resubscribe to ensure fresh state
    if (this.isConnected()) {
      console.log(`[BotService] Subscribing to agent: ${agent.name} (force: ${isDocumentChange && !isAgentChange})`);
      console.log(`🔗 [BotService] SUBSCRIPTION DETAILS:`, {
        agentName: agent.name,
        botId: agent.bot,
        participantId: this.getParticipantId(),
        isConnected: this.isConnected()
      });
      
      try {
        // Subscribe to the agent's bot for chat messages
        await this.socketSDK.subscribeToAgent(
          agent.bot,
          this.getParticipantId()
        );
        console.log(`✅ [BotService] Successfully subscribed to bot: ${agent.bot}`);
      } catch (error) {
        console.error(`❌ [BotService] Failed to subscribe to agent bot: ${agent.name}`, error);
        throw error;
      }
      
      // Always load conversation history for new context
      await this.loadConversationHistory(agent);
    }
  }

  private async loadConversationHistory(agent: Bot, retryCount = 0): Promise<void> {
    // Check if history already loaded for this agent
    if (this.historyLoadedForAgent === agent.bot) {
      console.log(`[BotService] ✅ History already loaded for ${agent.name}, skipping duplicate request`);
      return;
    }

    // Prevent concurrent history loading
    if (this.isLoadingHistory) {
      console.log(`[BotService] ⏸️  History loading already in progress for ${agent.name}, skipping duplicate request`);
      return;
    }

    const maxRetries = 3;
    const retryDelay = 1000; // 1 second

    try {
      this.isLoadingHistory = true;
      console.log(`[BotService] Loading conversation history for participant: ${this.getParticipantId()}`);
      
      // Ensure scope parameter is never undefined (which might be dropped by SDK)
      const scope = this.options.documentId || undefined;
      console.log(`[BotService] 🔍 GetThreadHistory call - bot: ${agent.bot}, participant: ${this.getParticipantId()}, scope: ${scope}`);
      
      // Load conversation history - increased page size for better initial load
      await this.socketSDK.getThreadHistory(
        agent.bot,
        this.getParticipantId(),
        1,
        20,
        scope
      );
      
      console.log(`[BotService] ✅ History loaded successfully for ${agent.name}`);
      this.historyLoadedForAgent = agent.bot;
    } catch (error) {
      console.error(`[BotService] ❌ Failed to load history (attempt ${retryCount + 1}):`, error);
      
      // Retry loading history if it fails (important for URL route access)
      if (retryCount < maxRetries) {
        console.log(`[BotService] Retrying history load in ${retryDelay}ms...`);
        setTimeout(() => {
          this.isLoadingHistory = false; // Reset flag before retry
          this.loadConversationHistory(agent, retryCount + 1);
        }, retryDelay);
        return; // Don't reset flag yet, will be reset in retry
      } else {
        console.error(`[BotService] 🚨 Failed to load history after ${maxRetries} attempts`);
        this.options.onError?.('Failed to load conversation history');
      }
    } finally {
      this.isLoadingHistory = false;
    }
  }

  async sendMessage(text: string): Promise<void> {
    if (!this.currentAgent) {
      throw new Error('No agent selected');
    }

    if (!this.isConnected()) {
      throw new Error('Not connected to server');
    }

    const requestId = `msg-${Date.now()}-${++this.messageCounter}`;
    const message = {
      requestId,
      participantId: this.getParticipantId(),
      workflow: this.currentAgent.bot,
      type: 'Chat' as const,
      scope: this.options.documentId,
      text,
      data: this.getMessageData(),
    };

    // Notify that a chat request was sent
    this.options.onChatRequestSent?.(requestId);

    await this.socketSDK.sendInboundMessage(message, MessageType.Chat);
  }

  async sendData(data: Record<string, unknown>): Promise<void> {
    if (!this.currentAgent) {
      throw new Error('No agent selected');
    }

    if (!this.isConnected()) {
      throw new Error('Not connected to server');
    }

    const message = {
      requestId: `data-${Date.now()}-${++this.messageCounter}`,
      participantId: this.getParticipantId(),
      workflow: this.currentAgent.bot,
      type: 'Data' as const,
      scope: this.options.documentId,
      data: {
        ...data,
        ...this.getMessageData(),
      },
    };

    await this.socketSDK.sendInboundMessage(message, MessageType.Data);
  }

  private getParticipantId(): string {
    return this.options.participantId || getSDKConfig().participantId;
  }

  private getMessageData(): Record<string, unknown> {
    const data: Record<string, unknown> = {};
    
    if (this.options.documentId) {
      data.documentId = this.options.documentId;
    }
    return data;
  }

  private handleChatMessage(message: Message): void {
    if(message.scope !== this.options.documentId) {
      console.warn('[BotService] Chat message received but not for this document:', message.id, message.data);
      return;
    }
    console.log('🎯 [BotService] INCOMING MESSAGE RECEIVED:', {
      id: message.id,
      text: message.text,
      messageType: message.messageType,
      requestId: message.requestId,
      direction: message.direction,
      workflowId: message.workflowId
    });
    
    // Check if this is a Chat response with a requestId
    if (message.requestId && message.messageType === 'Chat') {
      this.options.onChatResponseReceived?.(message.requestId);
    }
    
    const chatMessage = this.convertToChatMessage(message, 'agent');
    if (chatMessage.content === '') {
      console.log('⚠️ [BotService] Empty message content, skipping');
      return;
    }
    
    console.log('✅ [BotService] Forwarding message to UI:', chatMessage);
    this.options.onMessageReceived?.(chatMessage);
  }

  private handleDataMessage(message: Message): void {
    if(message.scope !== this.options.documentId) {
      console.warn('[BotService] Data message received but not for this document:', message.id, message.data);
      return;
    }

    console.log('[BotService] Data message received:', message.id, message.data);
    
    // Notify subscribers about the data message
    this.options.onDataMessageReceived?.(message);
  }

  private handleHandoffMessage(message: Message): void {
    const displayText = message.text || 'Handoff request processed';
    const chatMessage = this.convertToChatMessage(
      { ...message, text: displayText }, 
      'agent'
    );
    this.options.onMessageReceived?.(chatMessage);
  }

  private handleThreadHistory(history: Message[]): void {
    if (history.length === 0) {
      console.log('[BotService] No conversation history found');
      return;
    }

    // Create a hash of the history to detect duplicates
    const historyIds = history.map(m => m.id).sort().join(',');
    const historyHash = `${history.length}-${historyIds}`;
    
    if (this.processedHistoryHashes.has(historyHash)) {
      console.log(`[BotService] 🔄 Skipping duplicate history batch (${history.length} messages)`);
      return;
    }
    
    this.processedHistoryHashes.add(historyHash);
    console.log(`[BotService] Processing ${history.length} history messages`);
    
    // Filter out Data type messages from history
    // Data messages typically have data but minimal or no text content
    const filteredHistory = history.filter(message => {
      if (message.messageType === MessageType.Data) {
        return false;
      }
      return true; // Keep all other messages
    });
    
    if (filteredHistory.length < history.length) {
      console.log(`[BotService] Filtered out ${history.length - filteredHistory.length} Data messages from history`);
    }
    
    // Sort messages by creation date to ensure proper chronological order
    const sortedHistory = [...filteredHistory].sort((a, b) => {
      const dateA = new Date(a.createdAt || 0).getTime();
      const dateB = new Date(b.createdAt || 0).getTime();
      return dateA - dateB;
    });

    // Convert history messages and send them in chronological order
    // Mark them as history messages so UI can handle duplicates
    sortedHistory.forEach((message, index) => {
      const sender = message.direction === 'Incoming' ? 'user' : 'agent';
      const chatMessage = this.convertToChatMessage(message, sender);
      chatMessage.metadata = {
        ...chatMessage.metadata,
        isHistoryMessage: true
      };
      
      // Add a small delay between messages to prevent UI flooding
      setTimeout(() => {
        this.options.onMessageReceived?.(chatMessage);
      }, index * 10); // 10ms delay between each message
    });

    console.log(`[BotService] ✅ Loaded ${sortedHistory.length} messages from conversation history (${history.length - filteredHistory.length} Data messages filtered out)`);
  }

  private convertToChatMessage(message: Message, sender: 'user' | 'agent'): ChatMessage {
    return {
      id: message.id || `msg-${Date.now()}-${Math.random()}`,
      content: message.text || '',
      sender,
      timestamp: message.createdAt ? new Date(message.createdAt) : new Date(),
      type: 'text',
      metadata: {
        socketMessage: message,
        workflow: message.workflowType,
      },
    };
  }

  private handleConnected(): void {
    console.log('[BotService] ✅ Connected to server - updating UI state');
    this.options.onConnectionStateChanged?.(true);
    
    // Note: Don't re-subscribe here as it will be handled by ChatPanel's useEffect
    // This prevents double subscription and duplicate history loading
  }

  private handleDisconnected(reason?: string): void {
    console.log(`[BotService] ❌ Disconnected: ${reason}`);
    this.options.onConnectionStateChanged?.(false);
  }

  private handleConnectionError(error: { statusCode: number; message: string }): void {
    console.error('[BotService] 🚨 Connection error:', error);
    this.options.onError?.(`Connection error: ${error.message}`);
  }

  private handleError(error: string): void {
    console.error('[BotService] 🚨 Error:', error);
    this.options.onError?.(error);
  }

  async dispose(): Promise<void> {
    // Reset any loading state
    this.isLoadingHistory = false;
    this.currentAgent = null;
    this.processedHistoryHashes.clear();
    this.historyLoadedForAgent = null;
    
    await this.socketSDK.dispose();
  }
}