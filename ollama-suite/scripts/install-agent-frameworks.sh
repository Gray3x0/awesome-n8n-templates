#!/bin/bash

################################################################################
# Agent Frameworks Installation Module
# Installs: CrewAI, LangChain, LangGraph, AutoGPT, Semantic Kernel
################################################################################

source "$(dirname "$0")/../install-ollama-suite.sh" 2>/dev/null || true

install_agent_frameworks() {
    print_header "Installing Agent Frameworks"

    install_crewai
    install_langchain
    install_langgraph
    install_autogpt
    install_semantic_kernel
    install_phidata

    print_status "All agent frameworks installed!"
}

install_crewai() {
    print_status "Installing CrewAI..."

    pip install crewai crewai-tools --break-system-packages 2>/dev/null || \
    pip install crewai crewai-tools

    # Create example multi-agent system
    cat > "$PROJECTS_DIR/crewai_example.py" << 'EOF'
#!/usr/bin/env python3
"""
CrewAI Multi-Agent Example with Ollama
Optimized for GTX 1060 6GB
"""

from crewai import Agent, Task, Crew, Process
from langchain_community.llms import Ollama
import os

# Configure Ollama LLM
llm = Ollama(
    model="deepseek-r1:7b",
    base_url="http://localhost:11434"
)

# Create specialized agents
researcher = Agent(
    role='Research Specialist',
    goal='Conduct thorough research on given topics',
    backstory='''You are an expert researcher with years of experience
    in gathering and analyzing information from various sources.''',
    llm=llm,
    verbose=True,
    allow_delegation=False
)

analyst = Agent(
    role='Data Analyst',
    goal='Analyze research findings and extract insights',
    backstory='''You are a skilled data analyst who excels at finding
    patterns and drawing meaningful conclusions from research.''',
    llm=llm,
    verbose=True,
    allow_delegation=False
)

writer = Agent(
    role='Technical Writer',
    goal='Create clear, comprehensive documentation',
    backstory='''You are an experienced technical writer who can transform
    complex information into easy-to-understand documentation.''',
    llm=llm,
    verbose=True,
    allow_delegation=False
)

def run_research_crew(topic):
    """Run a multi-agent research crew"""

    # Define tasks
    research_task = Task(
        description=f'''Research the following topic: {topic}
        Gather comprehensive information including:
        - Key concepts and definitions
        - Current state and recent developments
        - Important considerations
        ''',
        agent=researcher,
        expected_output='Detailed research report with key findings'
    )

    analysis_task = Task(
        description='''Analyze the research findings and:
        - Identify key patterns and trends
        - Extract actionable insights
        - Highlight important takeaways
        ''',
        agent=analyst,
        expected_output='Analysis report with insights and recommendations'
    )

    writing_task = Task(
        description='''Create a comprehensive guide that:
        - Synthesizes research and analysis
        - Presents information in a clear structure
        - Includes practical recommendations
        ''',
        agent=writer,
        expected_output='Professional guide document'
    )

    # Create crew
    crew = Crew(
        agents=[researcher, analyst, writer],
        tasks=[research_task, analysis_task, writing_task],
        process=Process.sequential,
        verbose=True
    )

    # Execute
    result = crew.kickoff()
    return result

if __name__ == "__main__":
    import sys

    topic = sys.argv[1] if len(sys.argv) > 1 else "Artificial Intelligence in Healthcare"

    print(f"\n{'='*60}")
    print(f"Starting CrewAI Research on: {topic}")
    print(f"{'='*60}\n")

    result = run_research_crew(topic)

    print(f"\n{'='*60}")
    print("FINAL RESULT")
    print(f"{'='*60}\n")
    print(result)
EOF

    chmod +x "$PROJECTS_DIR/crewai_example.py"

    print_status "CrewAI installed!"
    print_info "Example: $PROJECTS_DIR/crewai_example.py"
}

install_langchain() {
    print_status "Installing LangChain..."

    pip install langchain langchain-community langchain-core \
        --break-system-packages 2>/dev/null || \
    pip install langchain langchain-community langchain-core

    # Create comprehensive example
    cat > "$PROJECTS_DIR/langchain_example.py" << 'EOF'
#!/usr/bin/env python3
"""
LangChain Example with Ollama
Demonstrates: Chains, Memory, Tools
"""

from langchain_community.llms import Ollama
from langchain.chains import LLMChain, ConversationChain
from langchain.memory import ConversationBufferMemory
from langchain.prompts import PromptTemplate
from langchain.agents import Tool, initialize_agent, AgentType
import sys

# Initialize Ollama
llm = Ollama(
    model="deepseek-r1:7b",
    base_url="http://localhost:11434",
    temperature=0.7
)

def simple_chain_example():
    """Simple LLM Chain"""
    template = """Question: {question}

Answer: Let's think step by step."""

    prompt = PromptTemplate(template=template, input_variables=["question"])
    chain = LLMChain(prompt=prompt, llm=llm)

    response = chain.run("What are the key benefits of local LLM deployment?")
    print(response)

def conversation_with_memory():
    """Conversation with memory"""
    memory = ConversationBufferMemory()
    conversation = ConversationChain(
        llm=llm,
        memory=memory,
        verbose=True
    )

    print("\nConversation Example:")
    print("-" * 50)
    response1 = conversation.predict(input="Hi, I'm working on a local AI project")
    print(f"AI: {response1}\n")

    response2 = conversation.predict(input="What did I just tell you I'm working on?")
    print(f"AI: {response2}\n")

def agent_with_tools():
    """Agent with custom tools"""

    # Define tools
    def search_tool(query: str) -> str:
        return f"Search results for: {query}"

    def calculator_tool(expression: str) -> str:
        try:
            return str(eval(expression))
        except:
            return "Invalid expression"

    tools = [
        Tool(
            name="Search",
            func=search_tool,
            description="Useful for searching information"
        ),
        Tool(
            name="Calculator",
            func=calculator_tool,
            description="Useful for mathematical calculations"
        )
    ]

    # Create agent
    agent = initialize_agent(
        tools,
        llm,
        agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
        verbose=True
    )

    response = agent.run("What is 25 * 4 + 10?")
    print(response)

if __name__ == "__main__":
    choice = sys.argv[1] if len(sys.argv) > 1 else "1"

    if choice == "1":
        print("Running Simple Chain Example...")
        simple_chain_example()
    elif choice == "2":
        print("Running Conversation with Memory...")
        conversation_with_memory()
    elif choice == "3":
        print("Running Agent with Tools...")
        agent_with_tools()
    else:
        print("Usage: python langchain_example.py [1|2|3]")
        print("  1: Simple Chain")
        print("  2: Conversation with Memory")
        print("  3: Agent with Tools")
EOF

    chmod +x "$PROJECTS_DIR/langchain_example.py"

    print_status "LangChain installed!"
}

install_langgraph() {
    print_status "Installing LangGraph..."

    pip install langgraph langchain-ollama --break-system-packages 2>/dev/null || \
    pip install langgraph langchain-ollama

    # Create advanced RAG example
    cat > "$PROJECTS_DIR/langgraph_adaptive_rag.py" << 'EOF'
#!/usr/bin/env python3
"""
LangGraph Adaptive RAG Example
Implements: Routing, Self-Correction, Hallucination Detection
"""

from typing import TypedDict, List
from langchain_ollama import ChatOllama
from langgraph.graph import StateGraph, END
import sys

# Define state
class GraphState(TypedDict):
    question: str
    generation: str
    documents: List[str]
    route: str

# Initialize LLM
llm = ChatOllama(model="deepseek-r1:7b", base_url="http://localhost:11434")

def route_question(state: GraphState) -> GraphState:
    """Route question to appropriate path"""
    question = state["question"]

    # Simple routing logic (can be enhanced with classifier)
    if "code" in question.lower() or "python" in question.lower():
        state["route"] = "coding"
    elif "math" in question.lower() or "calculate" in question.lower():
        state["route"] = "math"
    else:
        state["route"] = "general"

    print(f"Routing to: {state['route']}")
    return state

def retrieve_documents(state: GraphState) -> GraphState:
    """Retrieve relevant documents"""
    # Placeholder - integrate with actual vector DB
    state["documents"] = [
        "Document 1: Relevant information...",
        "Document 2: More context..."
    ]
    print("Documents retrieved")
    return state

def generate_answer(state: GraphState) -> GraphState:
    """Generate answer based on documents"""
    question = state["question"]
    docs = state["documents"]

    prompt = f"""Answer the question based on the context below.

Context: {' '.join(docs)}

Question: {question}

Answer:"""

    response = llm.invoke(prompt)
    state["generation"] = response.content
    print("Answer generated")
    return state

def check_hallucination(state: GraphState) -> str:
    """Check if answer is grounded in documents"""
    # Simplified check
    generation = state["generation"].lower()
    docs = ' '.join(state["documents"]).lower()

    # If key terms from answer appear in docs, likely not hallucination
    if any(word in docs for word in generation.split()[:10]):
        print("Answer appears grounded")
        return "useful"
    else:
        print("Potential hallucination detected")
        return "not useful"

def web_search(state: GraphState) -> GraphState:
    """Fallback to web search"""
    print("Falling back to web search...")
    state["documents"] = ["Web search result: Additional information..."]
    return state

# Build graph
def build_rag_graph():
    workflow = StateGraph(GraphState)

    # Add nodes
    workflow.add_node("route", route_question)
    workflow.add_node("retrieve", retrieve_documents)
    workflow.add_node("generate", generate_answer)
    workflow.add_node("websearch", web_search)

    # Add edges
    workflow.set_entry_point("route")
    workflow.add_edge("route", "retrieve")
    workflow.add_edge("retrieve", "generate")

    # Conditional edge based on hallucination check
    workflow.add_conditional_edges(
        "generate",
        check_hallucination,
        {
            "useful": END,
            "not useful": "websearch"
        }
    )
    workflow.add_edge("websearch", "generate")

    return workflow.compile()

if __name__ == "__main__":
    question = sys.argv[1] if len(sys.argv) > 1 else "What is adaptive RAG?"

    graph = build_rag_graph()

    result = graph.invoke({
        "question": question,
        "generation": "",
        "documents": [],
        "route": ""
    })

    print("\n" + "="*60)
    print("FINAL ANSWER")
    print("="*60)
    print(result["generation"])
EOF

    chmod +x "$PROJECTS_DIR/langgraph_adaptive_rag.py"

    print_status "LangGraph installed!"
}

install_autogpt() {
    print_status "Installing AutoGPT..."

    cd "$PROJECTS_DIR"

    if [ -d "Auto-GPT" ]; then
        cd Auto-GPT
        git pull
    else
        git clone https://github.com/Significant-Gravitas/AutoGPT.git Auto-GPT
        cd Auto-GPT
    fi

    # Create Ollama configuration
    cat > .env << EOF
# Ollama Configuration
LLM_PROVIDER=ollama
OLLAMA_API_BASE=http://localhost:11434
OLLAMA_MODEL=deepseek-r1:7b
OLLAMA_EMBEDDING_MODEL=nomic-embed-text

# General Settings
MEMORY_BACKEND=local
MEMORY_INDEX=auto-gpt-memory

# Disable expensive features for 6GB VRAM
SMART_LLM=deepseek-r1:7b
FAST_LLM=llama3.2:3b
EOF

    print_status "AutoGPT installed!"
    print_info "Directory: $PROJECTS_DIR/Auto-GPT"
    print_warning "Run setup: cd Auto-GPT && ./run.sh setup"
}

install_semantic_kernel() {
    print_status "Installing Microsoft Semantic Kernel..."

    pip install semantic-kernel --break-system-packages 2>/dev/null || \
    pip install semantic-kernel

    # Create example
    cat > "$PROJECTS_DIR/semantic_kernel_example.py" << 'EOF'
#!/usr/bin/env python3
"""
Semantic Kernel Example with Ollama
"""

import asyncio
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.ollama import OllamaChatCompletion

async def main():
    # Initialize kernel
    kernel = Kernel()

    # Add Ollama service
    kernel.add_service(
        OllamaChatCompletion(
            ai_model_id="deepseek-r1:7b",
            url="http://localhost:11434"
        )
    )

    # Create semantic function
    prompt = """
    {{$input}}

    Provide a comprehensive analysis including:
    1. Key points
    2. Implications
    3. Recommendations
    """

    analyze_function = kernel.create_function_from_prompt(
        function_name="analyze",
        plugin_name="analysis",
        prompt=prompt,
        max_tokens=2000
    )

    # Execute
    result = await kernel.invoke(
        analyze_function,
        input="Explain the benefits of local LLM deployment"
    )

    print(result)

if __name__ == "__main__":
    asyncio.run(main())
EOF

    chmod +x "$PROJECTS_DIR/semantic_kernel_example.py"

    print_status "Semantic Kernel installed!"
}

install_phidata() {
    print_status "Installing Phidata..."

    pip install phidata --break-system-packages 2>/dev/null || \
    pip install phidata

    # Create example
    cat > "$PROJECTS_DIR/phidata_example.py" << 'EOF'
#!/usr/bin/env python3
"""
Phidata Multi-Modal Agent Example
"""

from phi.agent import Agent
from phi.model.ollama import Ollama

# Create agent
agent = Agent(
    model=Ollama(id="deepseek-r1:7b"),
    description="You are a helpful AI assistant",
    markdown=True,
    show_tool_calls=True
)

# Run agent
agent.print_response("What are the advantages of using local LLMs?")
EOF

    chmod +x "$PROJECTS_DIR/phidata_example.py"

    print_status "Phidata installed!"
}

export -f install_agent_frameworks
