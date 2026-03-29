# Function Description / 功能说明

This Action can delete Releases and Workflow run logs of a specified repository.

此 Action 可删除指定仓库的 Releases 和 Workflow 运行记录。

## Instructions / 使用说明

You can use this Action by referencing it in a `.github/workflows/*.yml` workflow script, as shown in [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml).

在 `.github/workflows/*.yml` 工作流脚本中引用此 Action 即可使用，示例参见 [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml)。

```yaml
- name: Delete releases and workflows runs
  uses: ophub/delete-releases-workflows@main
  with:
    delete_releases: true
    releases_keep_latest: 5
    delete_workflows: true
    workflows_keep_day: 10
    gh_token: ${{ secrets.GITHUB_TOKEN }}
```

## Configuration / 配置说明

The following options can be configured in the delete.yml file:

可在 delete.yml 文件中配置以下选项：

| Key / 选项               | Required   | Description / 说明                       |
| ----------------------- | ---------- | ---------------------------------------- |
| delete_releases         | `Required`<br />`必选项` | Whether to delete Releases (options: `true`/`false`). Default: `false`.<br />是否删除 Releases（选项：`true`/`false`），默认为 `false`。 |
| prerelease_option       | Optional<br />可选项 | Filter the scope of Releases by pre-release status (options: `all`/`true`/`false`). `all` processes all Releases; `true` processes only pre-releases; `false` processes only non-pre-releases. Keyword and retention filters are applied within the filtered scope. Default: `all`.<br />按预发布状态筛选待处理的 Releases 范围（选项：`all`/`true`/`false`）。`all` 处理所有 Releases；`true` 仅处理预发布版本；`false` 仅处理正式版本。关键字和保留数量的过滤将在此筛选范围内执行。默认为 `all`。 |
| releases_keep_keyword   | Optional<br />可选项   | Keywords to match in Release tag names for preservation. Releases whose tag contains any keyword will ALL be preserved. Separate multiple keywords with `/` (e.g. `book/tool`). Default: none.<br />需要保留的 Release 标签（Tag）名称中的关键字，标签名包含任一关键字的 Release 将被全部保留。多个关键字以 `/` 分隔（例如：`book/tool`）。默认值：无。 |
| releases_keep_latest    | Optional<br />可选项 | Among Releases not matching any keyword, number of latest ones to keep (integer, e.g. `5`). Set to `0` to delete all non-keyword-matched Releases. Default: `90`.<br />在不包含关键字的 Releases 中，保留最新的数量（整数，如 `5`）。设置为 `0` 表示全部删除不含关键字的 Releases，默认保留 `90` 个。 |
| delete_tags             | Optional<br />可选项   | Whether to also delete tags associated with the deleted Releases (options: `true`/`false`). Default: `false`.<br />是否同时删除被删除的 Releases 所关联的标签（选项：`true`/`false`），默认为 `false`。 |
| delete_workflows        | `Required`<br />`必选项` | Whether to delete Workflow run records (options: `true`/`false`). Only completed runs are processed. Default: `false`.<br />是否删除 Workflow 运行记录（选项：`true`/`false`）。仅处理已完成（completed）的运行记录。默认为 `false`。 |
| workflows_keep_keyword  | Optional<br />可选项   | Keywords to match in Workflow run names for preservation. Workflow runs whose name contains any keyword will ALL be preserved. Separate multiple keywords with `/` (e.g. `book/tool`). Default: none.<br />需要保留的 Workflow 运行记录名称中的关键字，名称包含任一关键字的运行记录将被全部保留。多个关键字以 `/` 分隔（例如：`book/tool`）。默认值：无。 |
| workflows_keep_day      | Optional<br />可选项 | Among Workflow runs not matching any keyword, number of days to retain (integer, e.g. `30`). Set to `0` to delete all non-keyword-matched runs. Default: `90` days.<br />在不包含关键字的 Workflow 运行记录中，保留最近几天的记录（整数，如 `30`）。设置为 `0` 表示全部删除不含关键字的运行记录，默认为 `90` 天。 |
| out_log                 | Optional<br />可选项   | Whether to output detailed JSON logs for each step (options: `true`/`false`). Default: `false`.<br />是否输出每个步骤的详细 JSON 日志（选项：`true`/`false`），默认为 `false`。 |
| repo                    | Optional<br />可选项   | Target repository in `<owner>/<repo>` format. Default: the current repository.<br />目标仓库，格式为 `<owner>/<repo>`。默认为当前仓库。 |
| gh_token                | `Required`<br />`必选项` | [GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication) used to authenticate the delete operations.<br />用于验证删除操作的 [GITHUB_TOKEN](https://docs.github.com/zh/actions/security-guides/automatic-token-authentication#about-the-github_token-secret)。 |

- Each run can fetch up to 10,000 Releases and 10,000 Workflow run records (100 per page × 100 pages). If more records exist, run the action multiple times.
- 每次运行最多可获取 10,000 个 Releases 和 10,000 条 Workflow 运行记录（每页 100 条 × 最多 100 页）。如果记录数超出上限，需多次执行该操作。

## Links / 链接

- [GitHub Docs](https://docs.github.com/en/rest/releases/releases?list-releases)
- [unifreq/openwrt_packit](https://github.com/unifreq/openwrt_packit)
- [amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian)
- [amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt)
- [flippy-openwrt-actions](https://github.com/ophub/flippy-openwrt-actions)

## License / 许可协议

delete-releases-workflows © OPHUB is licensed under [GPL-2.0](https://github.com/ophub/delete-releases-workflows/blob/main/LICENSE).
