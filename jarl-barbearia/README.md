# JARL Barbearia — MVP

App de agendamento para barbearia com tema viking. Projeto de exemplo da FLK! Studios.

- **Agendar**: cliente escolhe ritual, barbeiro, dia e horário e deixa nome e WhatsApp.
- **Painel do barbeiro**: agenda do dia, faturamento previsto, marcar atendido ou cancelar.
- **Marca e nomes**: conceito, nomes sugeridos, cores, tipografia e tom de voz.

Publicado em `/jarl-barbearia/` no GitHub Pages do repositório.

## Modos

Sem `url` e `key` em `config.js`, o app roda em **modo demonstração**: clientes de exemplo, reservas salvas só no navegador.

Com o Supabase configurado, vira **modo real**: reservas no banco, painel com login.

## Banco (Supabase)

O banco fica no projeto **Pandherya**, no schema separado `jarl` (o plano grátis só permite 2 projetos ativos).

1. `supabase/schema.sql` já foi aplicado: tabelas, RLS, funções `criar_reserva` e `horarios_ocupados` e dados da JARL.
2. **Pendente:** em Settings > Data API > Exposed schemas, adicionar `jarl`. Até isso, o app cai sozinho no modo demonstração.
3. Para o painel: criar o usuário do barbeiro em Authentication > Users e vinculá-lo com o `insert into jarl.membros` no fim do schema.

Para mudar para um projeto próprio no futuro, rode o mesmo `schema.sql` lá e troque `url` e `key` em `config.js`.

## Segurança

- Cliente anônimo só lê barbeiros e serviços ativos e só cria reserva pela função `criar_reserva`, que valida horário, dia fechado e conflito.
- Nome e WhatsApp dos clientes só aparecem para membros logados da barbearia.
- Um índice único impede duas reservas ativas do mesmo barbeiro no mesmo horário.

## Próximos passos

- Confirmação e lembrete por WhatsApp (Z-API, Evolution API ou WhatsApp Cloud API via Edge Function).
- Bloquear horários pela duração do serviço (hoje cada reserva ocupa um bloco de 30 min).
- Cadastro de serviços, barbeiros e folgas pelo próprio painel.
- Cartão de runas real, ligado ao WhatsApp do cliente.
- Template multi-barbearia: `?b=slug` ou subdomínio por cliente.
