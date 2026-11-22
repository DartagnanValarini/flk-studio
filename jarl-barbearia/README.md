# JARL Barbearia — MVP

App de agendamento para barbearia com tema viking. Projeto de exemplo da FLK! Studios.

- **Agendar**: cliente escolhe ritual, barbeiro, dia e horário e deixa nome e WhatsApp.
- **Painel do barbeiro**: agenda do dia, faturamento previsto, marcar atendido ou cancelar.
- **Marca e nomes**: conceito, nomes sugeridos, cores, tipografia e tom de voz.

Publicado em `/jarl-barbearia/` no GitHub Pages do repositório.

## Modos

Sem `url` e `key` em `config.js`, o app roda em **modo demonstração**: clientes de exemplo, reservas salvas só no navegador.

Com o Supabase configurado, vira **modo real**: reservas no banco, painel com login.

## Ligar ao Supabase

1. Crie um projeto (região `sa-east-1`, São Paulo).
2. Rode `supabase/schema.sql` no SQL Editor. Ele cria as tabelas, as regras de acesso (RLS), as funções `criar_reserva` e `horarios_ocupados` e os dados da JARL.
3. Em Authentication > Users, crie o usuário do barbeiro e vincule com o `insert into public.membros` no fim do schema.
4. Preencha `config.js` com a URL do projeto e a chave publishable.

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
