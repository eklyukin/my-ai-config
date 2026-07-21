# SQLMesh Read Patterns — GitLab API Reference

## GitLab API base

Project path (URL-encoded): `data-platform%2Fsqlmesh`  
Base URL prefix for all calls: `/projects/data-platform%2Fsqlmesh`

All read calls: `neuronet_gitlab(action: "api", path: "...", useUserCredentials: true)`  
For write operations, see `WRITE_PATTERNS.md`.

**Pagination:** Search API returns up to 20 results per page. Check `X-Total-Pages` header; page with `&page=2`, `&page=3`, etc.

**Active model definition:** active = exists in repo AND no `enabled false` AND no `end '<past-date>'` in the MODEL block.

---

## Who owns a model?

1. Blob search for the model name:
   `/projects/data-platform%2Fsqlmesh/search?scope=blobs&search=<model_name>`
   → returns file paths containing that term.
2. Read the file raw:
   `/projects/data-platform%2Fsqlmesh/repository/files/<URL-ENCODED-PATH>/raw?ref=master`
   (encode every `/` in the path as `%2F`)
3. Extract `owner` value from MODEL block → reply with owner string + full model `name`.

---

## List models I own

1. Search for owner code:
   `/projects/data-platform%2Fsqlmesh/search?scope=blobs&search=owner+%27<OWNER_CODE>%27`
   (ask the user for their team code if unknown)
2. Filter results to `analytics` or `transfer` layer paths only.
3. Return list as `<schema>.<model>` sorted alphabetically.

---

## Active models count / list

Efficient approach (inverted search):
1. List all `.sql` files under `projects/xsolla-dwh/models/`:
   `/projects/data-platform%2Fsqlmesh/repository/tree?path=projects%2Fxsolla-dwh%2Fmodels&recursive=true&per_page=100`
   Page through with `&page=2` etc. if `X-Next-Page` is present.
2. Search for disabled models (faster than reading every file):
   - Search for `enabled false`: `/search?scope=blobs&search=enabled+false`
   - Search for `end '20`: `/search?scope=blobs&search=end+%2720` (catches dates like `'2024-...`, `'2025-...`)
3. Subtract disabled set from total → report count + optional list.

---

## Which models depend on mine? (downstream dependencies)

1. Search for the model's qualified name:
   `/projects/data-platform%2Fsqlmesh/search?scope=blobs&search=<schema>.<model_name>`
   → finds files that reference it in their SQL.
2. Filter to `.sql` files under `models/` only (exclude `audits/`, `tests/`, `macros/`).
3. For each hit, confirm it's a genuine `FROM`/`JOIN` reference (not a comment line).
4. Return list as `<schema>.<model>`.
