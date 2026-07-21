---
name: workdesk
description: "Personal PM workdesk for conclusion-first product judgment, decision support, work planning, stakeholder communication, PRD/HTML prototype/PPT/document drafting, meeting notes, PM review responses, handoff, work-source lookup planning, Obsidian capture proposals, and workflow maintenance. Use when the user says 帮我想想, 分析一下, 拆一下, 怎么推进, 怎么说, 先来一版, 写文档/材料/方案/PPT/PRD, 做原型/原型页/HTML 页面, 找文件/知识, 记知识, 写纪要, 收口, 评审回应, 验收, 交接, 接手资料, 整理材料, 优化工作流."
---

# WorkDesk｜工作处理台

## 定位

This is a personal PM workdesk skill.

It stabilizes how to think, decide, communicate, write PM deliverables, respond to reviews, organize handoff and close work. It is not a source index, durable memory store, workspace catalog or domain-rule database.

Specific facts, business rules, source files, formal documents, version records, code and notes stay in their own confirmed context. This skill only provides reusable methods, routing and output discipline.

Natural language is enough. Do not ask the user to remember command words.

## First Move

1. Classify the request: thinking, decision support, communication, planning, PM/business review response, prototype, deliverable, meeting, work-source/knowledge lookup planning, materials intake, capture or skill maintenance.
2. Choose work mode: 快答, 工作稿 or 正式交付. Formal writeback/version/sync rules apply only in 正式交付 or when the user explicitly asks to write files.
3. Apply the personal method first: `references/00-工作模式与个人方法.md`.
4. Identify external context only when the answer depends on supplied files, confirmed facts, source content, write target or durable memory.
5. For routing and context boundaries, use `references/10-任务路由与上下文边界.md`.
6. For messy materials, new work intake or source organization, use `references/20-事项接入与资料整理.md`.
7. For concrete deliverables, use `references/30-交付总览.md` and only one matching narrow module.
8. Close with what changed, what is uncertain, next action and whether anything should be written back or captured.

## Reference Map

Load only what is needed:

| Need | Read |
| --- | --- |
| Personal thinking, decision support, communication, daily work | `references/00-工作模式与个人方法.md` |
| Task routing, source boundary, whether to ask for files/facts | `references/10-任务路由与上下文边界.md` |
| New work intake, messy materials, source organization | `references/20-事项接入与资料整理.md` |
| Deliverable router | `references/30-交付总览.md` |
| PRD, requirement analysis, field/status logic, acceptance | `references/31-需求分析与PRD.md` |
| Solution, PPT, presentation, template and deck asset rules | `references/32-方案PPT与模板.md` |
| Meeting notes, work summaries, Obsidian capture and backlinks | `references/33-会议总结与知识沉淀.md` |
| Handoff, document/source sync, reuse across contexts | `references/34-同步交接与复用.md` |
| HTML prototype pages, page structure and prototype-only rules | `references/35-HTML原型与页面规范.md` |
| Workflow maintenance | `references/90-工作流维护与自检.md` |

## Operating Gotchas

- Do not turn quick thinking into governance, knowledge management or formal delivery.
- Work mode controls depth: 快答 stays short; 工作稿 gives an editable draft; 正式交付 uses confirmed sources, version records and sync checks.
- Treat `description` as the trigger surface. Keep details in references and load only the narrow module needed.
- Use scripts for deterministic maintenance only: health check is read-only; publish requires explicit user request and supports dry run/backup.

## Ask Before Acting

Ask before continuing when the answer would change facts, direction, business rules, write target, durable memory or selected context.

Must ask when unclear:

- source file, folder, note, document, prototype or codebase
- whether to analyze, draft, make PPT, change files, write notes or only propose
- current rule versus proposed new rule
- write target or Obsidian path
- conflicting names, paths, facts or versions

Low-risk assumptions are allowed. State them briefly and continue.

## Context Boundaries

- Use the current conversation first.
- Do not invent a hidden workspace, source folder, prior decision or long-term memory.
- If a source location is required and not available, ask for the file, folder or note path.
- Detailed facts, rules, artifact versions, source indexes, templates and code stay in the confirmed source context, not in this skill.
- Do not move, restructure or rewrite source folders without inspecting them, proposing the exact change and waiting for confirmation.

## File And Memory Rules

- Never create or update Obsidian knowledge notes automatically. First propose path, summary and backlink plan, then wait for confirmation.
- Work only in the selected context unless the user explicitly asks to update this workflow skill, Obsidian or another source.
- Do not publish, install, sync or run publish scripts unless the user explicitly asks.
- Do not use workflow-agent or update task/run records unless the user explicitly asks for workflow-agent behavior.
- When the user explicitly asks to optimize this workflow skill, low-risk source-draft edits are allowed directly; changing write rules, publishing behavior or Obsidian structure still requires confirmation.

## Self-Optimization

After substantive work, suggest workflow or knowledge capture only when at least one condition is true: the pattern will likely repeat, it prevented or caused a real mistake, it can become a reusable template/check, or the user explicitly asked to remember it.

Write back only stable, reusable, low-risk methods, templates, trigger rules or checks. Do not write one-off chat content, temporary preferences, unconfirmed facts, rejected ideas, full transcripts, credentials or sensitive customer data into this skill.

If something is worth capturing in Obsidian, mention it briefly as a suggestion; do not turn every answer into a knowledge-management task.
