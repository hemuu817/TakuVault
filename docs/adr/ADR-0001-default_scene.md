### default_scene（ADR-0001）
- default_scene は ADR-0001 に従い **position=1** として作成する（is_default は使わない）
- sessions:
  - user_id NOT NULL（所有権）
  - tool は Cocofolia 固定（enum/定数は任意だがMVPではUI/仕様として固定）
  - room_url は text 推奨（長くなる可能性があるため）

- scenes（本Issueでは「作成する」前提だけ共有）
  - position=1 は default_scene として常設（詳細は Issue #15）

## 受け入れ条件（Yes/No）
- [ ] default_scene は ADR-0001 に従い **position=1** のSceneである
- [ ] position=1 のSceneは削除できない（URL直打ちでも不可）
- [ ] position=1 のSceneは position を変更できない（空席化防止）

## DB要件（Usage複合FKの前提も含む）
- scenes:
  - session_id NOT NULL（FK）
  - position NOT NULL
  - name NOT NULL
  - `UNIQUE(session_id, position)`（position=1がdefaultの一意を担保）
  - `UNIQUE(session_id, id)`（usages複合FK成立用）

- （Relates：Epic D）usages:
  - `FOREIGN KEY (session_id, scene_id) REFERENCES scenes(session_id, id)`（複合FK）

  > default_scene の定義・不変条件は ADR-0001 を正とする（Issue本文への再掲は禁止）
