# Function description / 功能说明

This Actions can delete specified repository's Releases and Workflow run logs.

这个 Actions 可以删除指定仓库的 Releases 和 Workflows 运行记录。

## Instructions / 使用说明

You can use this Actions by introducing it in the `.github/workflows/*.yml` workflow script, such as in [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml).

在 `.github/workflows/*.yml` 工作流脚本中引入此 Actions 即可使用，例如 [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml)。

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

## Setting instructions / 设置说明

You can configure the following options in the delete.yml file:

您可以在 delete.yml 文件中使用以下选项进行配置：

| Key / 选项               | Required   | Description / 说明                       |
| ----------------------- | ---------- | ---------------------------------------- |
| delete_releases         | `Required`<br />`必选项` | Set whether to delete releases files (options: `true`/`false`). The default is `false`.<br />设置是否删除 releases 文件（选项：`true`/`false`），默认为 `false`。 |
| prerelease_option       | Optional<br />可选项 | Set whether to differentiate pre-release versions (options: `all`/`true`/`false`). `all` indicates all types, `true`/`false` represent only deleting releases files marked with this type. The default is `all`.<br />设置是否区分预发行版本（选项：`all`/`true`/`false`）。`all`表示全部类型，`true`/`false`代表仅删除标记为此类型的 releases 文件。默认为 `all`。 |
| releases_keep_latest    | Optional<br />可选项 | Set how many of the latest Releases versions to keep (`integer`, such as: 5). Setting to `0` means delete all, and the default is to keep `90`.<br />设置保留几个最新的 Releases 版本（`整数`。如：5），设置为 `0` 表示全部删除，默认保留 `90` 个。 |
| releases_keep_keyword   | Optional<br />可选项   | Set the `keywords` of the Releases' tags to be preserved. Multiple keywords are separated by `/` (for example: `book/tool`). The default value is `none`.<br />设置需要保留的 Releases 的 tags `关键字`，多个关键字使用 `/` 分割（例如：`book/tool`），默认值 `无`。 |
| delete_tags             | Optional<br />可选项   | Set whether to delete the tags associated with Releases (options: `true`/`false`). The default is `false`.<br />设置是否删除与 Releases 关联的 tags（选项：`true`/`false`），默认为 `false`。 |
| delete_workflows        | `Required`<br />`必选项` | Set whether to delete workflow run logs (options: `true`/`false`). The default is `false`.<br />设置是否删除 workflows 运行记录（选项：`true`/`false`），默认为 `false`。 |
| workflows_keep_day      | Optional<br />可选项 | Set how many days' workflow logs to keep (`integer`, such as: 30). Setting to `0` means delete all. The default is `90` days.<br />设置保留几天以内的 workflows 记录（`整数`。如：30），设置为 `0` 表示全部删除。默认为 `90` 天。 |
| workflows_keep_keyword  | Optional<br />可选项   | Set the `keywords` for the names of the workflow run logs to be kept. Multiple keywords are separated by `/` (for example: `book/tool`). The default value is `none`.<br />设置需要保留的 workflows 运行记录的名称`关键字`，多个关键字使用 `/` 分割（例如：`book/tool`），默认值 `无`。 |
| out_log                 | Optional<br />可选项   | Set whether to output detailed json logs (options: `true`/`false`). The default value is `false`.<br />设置是否输出详细的 json 日志（选项：`true`/`false`），默认值 `false`。 |
| repo                    | Optional<br />可选项   | Set the `<owner>/<repo>` for the execution operation, the default is the `current repository`.<br />设置执行操作的 `<owner>/<repo>` ，默认为`当前仓库`。 |
| gh_token                | `Required`<br />`必选项` | Set the [GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication) password for executing the delete operation.<br />设置执行删除操作的 [GITHUB_TOKEN](https://docs.github.com/zh/actions/security-guides/automatic-token-authentication#about-the-github_token-secret) 口令。 |

- Each run can delete up to 1000 Releases and 1000 Workflow run logs. If there are more records, the delete operation needs to be run multiple times.
- 每次运行可以删除 1000 个 Releases 和 1000 个 Workflows 运行记录，如有更多记录，需要多次运行删除操作。

## Links / 链接

- [GitHub Docs](https://docs.github.com/en/rest/releases/releases?list-releases)
- [unifreq/openwrt_packit](https://github.com/unifreq/openwrt_packit)
- [amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian)
- [amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt)
- [flippy-openwrt-actions](https://github.com/ophub/flippy-openwrt-actions)

## License / 许可

The delete-releases-workflows © OPHUB is licensed under [GPL-2.0](https://github.com/ophub/delete-releases-workflows/blob/main/LICENSE)
