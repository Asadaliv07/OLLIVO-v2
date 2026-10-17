"""
AirLLM Service Daemon CLI Entrypoint
"""

import argparse
import logging
import sys
import uvicorn

from .api import create_app
from .config import AirLLMConfig
from .model_manager import ModelManager


def parse_args():
    parser = argparse.ArgumentParser(description="Ollivo AirLLM Local Inference Service")
    parser.add_argument("--host", type=str, default=None, help="Host address to bind (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=None, help="Port to bind (default: 8765)")
    parser.add_argument("--model", type=str, default=None, help="Default model ID or path")
    parser.add_argument("--device", type=str, default=None, help="Device ('auto', 'cuda', 'mps', 'cpu')")
    parser.add_argument("--compression", type=str, default=None, help="Compression ('4bit', '8bit', 'none')")
    parser.add_argument("--mock", action="store_true", help="Run with mock inference engine for testing")
    parser.add_argument("--warmup", action="store_true", help="Preload model on startup")
    parser.add_argument("--log-level", type=str, default=None, help="Logging verbosity (DEBUG, INFO, WARNING, ERROR)")
    return parser.parse_args()


def main():
    args = parse_args()
    config = AirLLMConfig.from_env()

    if args.host:
        config.host = args.host
    if args.port:
        config.port = args.port
    if args.model:
        config.model_id = args.model
    if args.device:
        config.device = args.device
    if args.compression:
        config.compression = args.compression
    if args.mock:
        config.mock_mode = True
    if args.warmup:
        config.auto_warmup_on_startup = True
    if args.log_level:
        config.log_level = args.log_level.upper()

    logging.basicConfig(
        level=getattr(logging, config.log_level, logging.INFO),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    logger = logging.getLogger("airllm_service")
    logger.info("Initializing Ollivo AirLLM Local Service...")
    logger.info(f"Target model: {config.model_id} (compression={config.compression}, device={config.device})")
    logger.info(f"Free disk space on shard directory: {config.check_disk_space():.1f} GB")

    manager = ModelManager(config)
    app = create_app(config=config, model_manager=manager)

    uvicorn.run(
        app,
        host=config.host,
        port=config.port,
        log_level=config.log_level.lower(),
        access_log=False,
    )


if __name__ == "__main__":
    main()
