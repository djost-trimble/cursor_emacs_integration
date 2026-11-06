import { SessionOptions, Session, AgentMessage, AgentResponse } from './types';

export class AgentClient {
  private sessions: Map<string, any>;
  private apiKey?: string;
  private endpoint: string;

  constructor(apiKey?: string, endpoint?: string) {
    this.sessions = new Map();
    this.apiKey = apiKey || process.env.CURSOR_API_KEY;
    this.endpoint = endpoint || process.env.CURSOR_ENDPOINT || 'https://cursor.com/api';
  }

  async createSession(options: SessionOptions): Promise<Session> {
    const sessionId = this.generateSessionId();
    const session: Session = {
      id: sessionId,
      model: options.model || 'claude-4-sonnet',
      workspace: options.workspace,
      context: {
        workspace: options.workspace,
        files: options.files || []
      },
      createdAt: Date.now(),
      lastActive: Date.now()
    };

    this.sessions.set(sessionId, {
      ...session,
      messages: []
    });

    console.log(`Created session ${sessionId} with model ${session.model}`);
    return session;
  }

  async resumeSession(sessionId: string, sessionData: Session): Promise<Session> {
    if (!this.sessions.has(sessionId)) {
      this.sessions.set(sessionId, {
        ...sessionData,
        messages: []
      });
    }

    const session = this.sessions.get(sessionId);
    session.lastActive = Date.now();

    console.log(`Resumed session ${sessionId}`);
    return this.getSessionInfo(sessionId);
  }

  async sendMessage(sessionId: string, message: string, context?: any): Promise<AgentResponse> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.lastActive = Date.now();

    const userMessage = {
      role: 'user',
      content: message,
      timestamp: Date.now()
    };
    session.messages.push(userMessage);

    const response = await this.simulateAgentResponse(message, context);

    const assistantMessage = {
      role: 'assistant',
      content: response.content,
      timestamp: Date.now(),
      messageId: response.messageId
    };
    session.messages.push(assistantMessage);

    return response;
  }

  async streamResponse(
    sessionId: string,
    message: string,
    onChunk: (chunk: any) => void,
    context?: any
  ): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.lastActive = Date.now();

    const response = await this.simulateAgentResponse(message, context);
    const words = response.content.split(' ');

    for (const word of words) {
      await new Promise(resolve => setTimeout(resolve, 50));
      onChunk({ content: word + ' ', delta: word + ' ' });
    }

    onChunk({ done: true, messageId: response.messageId });
  }

  getSession(sessionId: string): any {
    return this.sessions.get(sessionId);
  }

  getSessionInfo(sessionId: string): Session {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    return {
      id: session.id,
      model: session.model,
      workspace: session.workspace,
      context: session.context,
      createdAt: session.createdAt,
      lastActive: session.lastActive
    };
  }

  listSessions(): Session[] {
    return Array.from(this.sessions.values()).map(session => ({
      id: session.id,
      model: session.model,
      workspace: session.workspace,
      context: session.context,
      createdAt: session.createdAt,
      lastActive: session.lastActive
    }));
  }

  deleteSession(sessionId: string): void {
    this.sessions.delete(sessionId);
    console.log(`Deleted session ${sessionId}`);
  }

  private generateSessionId(): string {
    return 'sess_' + Math.random().toString(36).substring(2, 15);
  }

  private async simulateAgentResponse(message: string, context?: any): Promise<AgentResponse> {
    const messageId = 'msg_' + Math.random().toString(36).substring(2, 15);

    let responseContent = '';
    const lowerMessage = message.toLowerCase();

    if (lowerMessage.includes('explain')) {
      responseContent = 'I\'ll explain this code for you. The function performs the following operations:\n\n1. First, it initializes the necessary variables\n2. Then it processes the input data\n3. Finally, it returns the result\n\nThis is a common pattern in software development.';
    } else if (lowerMessage.includes('fix') || lowerMessage.includes('error') || lowerMessage.includes('bug')) {
      responseContent = 'I found the issue. Here\'s the corrected code:\n\n```python\ndef fixed_function():\n    # Fixed implementation\n    result = process_data()\n    return result\n```\n\nThe problem was in the error handling. I\'ve updated it to properly handle edge cases.';
    } else if (lowerMessage.includes('refactor')) {
      responseContent = 'I\'ve refactored the code to improve readability and maintainability:\n\n```python\nasync def refactored_function():\n    """Improved function with better structure."""\n    data = await fetch_data()\n    processed = transform(data)\n    return processed\n```\n\nThe changes include:\n- Using async/await for better asynchronous handling\n- Adding docstrings\n- Breaking down complex operations';
    } else if (lowerMessage.includes('test')) {
      responseContent = 'Here are comprehensive tests for your code:\n\n```python\nimport pytest\n\ndef test_function():\n    """Test the main functionality."""\n    result = your_function(test_input)\n    assert result == expected_output\n\ndef test_edge_cases():\n    """Test edge cases."""\n    assert your_function(None) is None\n    assert your_function([]) == []\n```';
    } else {
      responseContent = `I understand your request: "${message}"\n\nI'm here to help with code analysis, refactoring, bug fixes, and explanations. For this request, I'll provide assistance based on the context you've shared.\n\nLet me know if you'd like me to focus on a specific aspect!`;
    }

    return {
      messageId,
      content: responseContent
    };
  }
}
