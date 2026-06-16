# Lemonade Setup

## Install

```bash
sudo add-apt-repository ppa:lemonade-team/stable
sudo apt install lemonade-server
```

## Verify

```bash
lemonade status
```

## Pull Models

```bash
lemonade pull Qwen3.6-35B-A3B-GGUF
lemonade pull Qwen3.5-9B-GGUF
```

## Load Model

```bash
lemonade load Qwen3.6-35B-A3B-GGUF --ctx-size 262144 --save-options
```
