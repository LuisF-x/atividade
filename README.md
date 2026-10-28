# Web_Crawler_Eleicao_2026

Atividade de Engenharia de Software (UniFacimp Wyden) aplicando Manifesto Ágil e Extreme Programming (XP).
O script `buscador.sh` consulta os resultados oficiais do TSE e mostra, em tabelas, os candidatos mais votados por cargo.

## Objetivo

Evoluir o script original por pair programming, em pequenas melhorias, para:

1. consultar **todos os municípios do Maranhão** (e não um município fixo);
2. mostrar **1º e 2º turno separadamente**, quando houver dados;
3. **indicar os candidatos eleitos**;
4. corrigir fragilidades e melhorar legibilidade, mensagens de erro e manutenção.

## Diagnóstico inicial (antes de alterar o código)

| # | Ponto encontrado | Melhoria planejada |
|---|------------------|--------------------|
| 1 | Município fixo (`07242`) | Buscar a lista de municípios do MA no TSE e percorrer todos; `-m` para um só |
| 2 | Nenhuma noção de turno | Opção `-t 1\|2\|all`; saída separada por turno |
| 3 | Eleitos não aparecem | Coluna `SITUAÇÃO` com `ELEITO`; eleitos nunca são cortados pelo limite |
| 4 | Qualquer falha em um cargo aborta tudo (`die`) | Cargo sem dados mostra aviso e o script segue (ex.: governador no MA não teve 2º turno) |
| 5 | Só configurável por variáveis de ambiente, sem ajuda | Opções `-t -m -n -h` e texto de ajuda |
| 6 | Saída mostra só o código do município | Cabeçalho com nome e código do município |
| 7 | Lógica em um laço único | Funções: `fetch`, `list_municipios`, `show_turno`, `show_cargo` |
| 8 | README vazio | Este documento |

## Pré-requisitos

- Bash 4.4+ (testado em 5.2), `curl` e `jq`
- `sudo apt install curl jq`

## Como executar

```bash
chmod +x buscador.sh
./buscador.sh -h                  # ajuda
./buscador.sh -t 1                # 1º turno, todos os municípios do MA
./buscador.sh -t 1 -m 07242       # 1º turno, um município
./buscador.sh -n 5                # top 5 por cargo (eleitos sempre aparecem)
```

### 2º turno

Cada turno é uma eleição independente no TSE, com código próprio. Os códigos do 1º turno já vêm no script.
Para o 2º turno, informe os códigos (copie da aba *Network* do navegador em resultados.tse.jus.br, na URL `.../ele2026/<CÓDIGO>/dados/...`):

```bash
export TSE_RESULTS_FEDERAL_ELECTION_T2=<codigo>   # presidente
export TSE_RESULTS_STATE_ELECTION_T2=<codigo>     # governador
./buscador.sh -t 2
```

Em 2026 só presidente e governador têm 2º turno, e o governador do Maranhão foi definido no 1º turno;
por isso, no MA o 2º turno traz apenas presidente, e governador aparece como "sem dados".

## Melhorias e correções realizadas

Preencher com os commits reais (um por item):

- [ ] Opções de linha de comando e ajuda
- [ ] Lista de municípios do MA obtida do TSE
- [ ] Separação por turno
- [ ] Coluna de eleitos
- [ ] Tratamento de cargos sem dados
- [ ] Refatoração em funções e mensagens de erro
- [ ] README

## Divisão do pair programming

| Ciclo | Driver | Navigator | O que foi feito |
|-------|--------|-----------|-----------------|
| 1 | _Aluno A_ | _Aluno B_ | Diagnóstico e README inicial |
| 2 | _Aluno B_ | _Aluno A_ | Municípios do MA |
| 3 | _Aluno A_ | _Aluno B_ | Turnos |
| 4 | _Aluno B_ | _Aluno A_ | Eleitos |
| 5 | _Aluno A_ | _Aluno B_ | Tratamento de erros e refatoração |

Papéis trocados a cada ciclo; o Navigator revisava, questionava e sugeria testes antes do commit.

## Evidências de validação

Colar aqui a saída real dos testes feitos pela dupla:

- [ ] `./buscador.sh -t 1 -m 07242` (um município, 1º turno)
- [ ] `./buscador.sh -t 1` (todos os municípios do MA)
- [ ] `./buscador.sh -t 2` com os códigos do 2º turno
- [ ] Sem `jq` instalado → mensagem de erro clara
- [ ] `-t 9` / `-m 123` → mensagem de parâmetro inválido
- [ ] Cargo sem dados (governador no 2º turno) → script continua
