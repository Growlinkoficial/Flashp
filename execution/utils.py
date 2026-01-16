import json
import os
from datetime import datetime

def log_execution(script_name: str, inputs: dict, outputs: dict, duration: float, status: str, error: str = None):
    """Logs script execution to a JSONL file."""
    log_dir = ".tmp/logs"
    os.makedirs(log_dir, exist_ok=True)
    today = datetime.now().strftime("%Y%m%d")
    log_file = os.path.join(log_dir, f"execution_{today}.jsonl")
    
    entry = {
        "timestamp": datetime.now().isoformat() + "Z",
        "script_name": script_name,
        "inputs": inputs,
        "outputs": outputs,
        "duration_seconds": duration,
        "status": status,
        "error": error
    }
    
    with open(log_file, "a") as f:
        f.write(json.dumps(entry) + "\n")

def log_decision(title: str, context: str, options: list, choice: str, reasoning: str, risk: str, scripts: list):
    """Logs agent decisions to a Markdown file."""
    log_dir = ".tmp/logs"
    os.makedirs(log_dir, exist_ok=True)
    today = datetime.now().strftime("%Y%m%d")
    log_file = os.path.join(log_dir, f"decisions_{today}.md")
    
    timestamp = datetime.now().strftime("%H:%M:%S")
    content = f"""
## [{timestamp}] Decision: {title}
**Context**: {context}
**Options Considered**: 
{chr(10).join([f"{i+1}. {opt}" for i, opt in enumerate(options)])}
**Choice**: {choice}
**Reasoning**: {reasoning}
**Risk Assessment**: {risk}
**Scripts Called**: {", ".join(scripts)}
---
"""
    with open(log_file, "a") as f:
        f.write(content)
