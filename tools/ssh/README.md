# Chaves SSH (VPS Oracle)

Chaves para acesso à VPS de produção.

| Arquivo | Descrição |
|---------|-----------|
| `ssh-key-2026-06-29.key` | Chave privada — **não versionada** |
| `ssh-key-2026-06-29.key.pub` | Chave pública — pode ser adicionada na VPS |

## Uso

```bash
ssh -i tools/ssh/ssh-key-2026-06-29.key usuario@IP_DA_VPS
```

## Segurança

A chave privada está listada no `.gitignore`. Nunca faça commit de arquivos `*.key` ou `*.pem`.
