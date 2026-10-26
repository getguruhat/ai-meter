import Foundation

/// The app's text in the first of the user's preferred languages that has a translation,
/// with English for any other language. "AI Meter", the provider names, and the "AI 79%"
/// menu bar title are the same in every language. Any property a translation doesn't set
/// stays English. Templates take {0}, {1}; fill them with `Strings.fill`.
struct Strings {
    static let current = Strings.for(Locale.preferredLanguages)

    /// Picks the first preferred language with a translation: "de-AT" uses German,
    /// "zh-Hans-CN" uses Simplified Chinese. Traditional Chinese falls back to English.
    static func `for`(_ languages: [String]) -> Strings {
        for language in languages {
            let code = language.hasPrefix("zh-Hans") ? "zh-Hans" : String(language.prefix { $0 != "-" && $0 != "_" })
            if code == "en" { return Strings() }
            if let strings = all[code] { return strings }
        }
        return Strings()
    }

    static func fill(_ template: String, _ values: CustomStringConvertible...) -> String {
        var text = template
        for (index, value) in values.enumerated() {
            text = text.replacingOccurrences(of: "{\(index)}", with: value.description)
        }
        return text
    }

    var provider = "Provider"
    var usageRemaining = "AI usage remaining: {0}%"
    var unavailable = "AI usage unavailable"
    var resets = "Resets {0}"
    var troubleshooting = "Open the troubleshooting guide ›"
    var refresh = "Refresh"
    var about = "About AI Meter"
    var quit = "Quit"
    var version = "Version {0}"
    var tagline = "A GuruHat open-source tool"
    var support = "Support AI Meter"
    var thanks = "Thank you for supporting this project!"
    var codexNoSignIn = "No Codex sign-in found. Run codex and sign in with ChatGPT."
    var codexExpired = "Codex sign-in expired. Run codex once to renew it."
    var claudeNoSignIn = "No Claude Code sign-in found in Terminal. Signing in to the Claude app isn't enough."
    var claudeExpiredAt = "Claude sign-in expired at {0}. Run claude in Terminal once to renew it."
    var claudeExpired = "Claude sign-in expired. Use Claude Code once to renew it."
    var unreachable = "Couldn't get usage from {0}. Trying again in 5 minutes."
    var rateLimited = "{0} is limiting usage checks. Next check at {1}."
    var updateTitle = "{0} {1} is available"
    var updateMessage = "You have version {0}. Download the new version from GitHub?"
    var download = "Download"
    var later = "Later"

    private static let all: [String: Strings] = [
        "es": {
            var s = Strings()
            s.provider = "Proveedor"
            s.usageRemaining = "Uso de IA restante: {0}%"
            s.unavailable = "Uso de IA no disponible"
            s.resets = "Se reinicia: {0}"
            s.troubleshooting = "Abrir la guía de solución de problemas ›"
            s.refresh = "Actualizar"
            s.about = "Acerca de AI Meter"
            s.quit = "Salir"
            s.version = "Versión {0}"
            s.tagline = "Una herramienta de código abierto de GuruHat"
            s.support = "Apoyar AI Meter"
            s.thanks = "¡Gracias por apoyar este proyecto!"
            s.codexNoSignIn = "No se encontró ningún inicio de sesión de Codex. Ejecuta codex e inicia sesión con ChatGPT."
            s.codexExpired = "El inicio de sesión de Codex caducó. Ejecuta codex una vez para renovarlo."
            s.claudeNoSignIn = "No se encontró ningún inicio de sesión de Claude Code en Terminal. Iniciar sesión en la app de Claude no es suficiente."
            s.claudeExpiredAt = "El inicio de sesión de Claude caducó a las {0}. Ejecuta claude una vez en Terminal para renovarlo."
            s.claudeExpired = "El inicio de sesión de Claude caducó. Usa Claude Code una vez para renovarlo."
            s.unreachable = "No se pudo obtener el uso de {0}. Se reintentará en 5 minutos."
            s.rateLimited = "{0} está limitando las consultas de uso. Próxima consulta a las {1}."
            s.updateTitle = "{0} {1} está disponible"
            s.updateMessage = "Tienes la versión {0}. ¿Quieres descargar la nueva versión desde GitHub?"
            s.download = "Descargar"
            s.later = "Más tarde"
            return s
        }(),
        "de": {
            var s = Strings()
            s.provider = "Anbieter"
            s.usageRemaining = "Verbleibende KI-Nutzung: {0} %"
            s.unavailable = "KI-Nutzung nicht verfügbar"
            s.resets = "Zurücksetzung: {0}"
            s.troubleshooting = "Anleitung zur Fehlerbehebung öffnen ›"
            s.refresh = "Aktualisieren"
            s.about = "Über AI Meter"
            s.quit = "Beenden"
            s.version = "Version {0}"
            s.tagline = "Ein Open-Source-Tool von GuruHat"
            s.support = "AI Meter unterstützen"
            s.thanks = "Vielen Dank für Ihre Unterstützung!"
            s.codexNoSignIn = "Keine Codex-Anmeldung gefunden. Führen Sie codex aus und melden Sie sich mit ChatGPT an."
            s.codexExpired = "Codex-Anmeldung abgelaufen. Führen Sie codex einmal aus, um sie zu erneuern."
            s.claudeNoSignIn = "Keine Claude Code-Anmeldung im Terminal gefunden. Die Anmeldung in der Claude-App reicht nicht aus."
            s.claudeExpiredAt = "Claude-Anmeldung um {0} abgelaufen. Führen Sie claude einmal im Terminal aus, um sie zu erneuern."
            s.claudeExpired = "Claude-Anmeldung abgelaufen. Verwenden Sie Claude Code einmal, um sie zu erneuern."
            s.unreachable = "Nutzung von {0} konnte nicht abgerufen werden. Neuer Versuch in 5 Minuten."
            s.rateLimited = "{0} begrenzt die Nutzungsabfragen. Nächste Abfrage um {1}."
            s.updateTitle = "{0} {1} ist verfügbar"
            s.updateMessage = "Sie haben Version {0}. Möchten Sie die neue Version von GitHub herunterladen?"
            s.download = "Herunterladen"
            s.later = "Später"
            return s
        }(),
        "fr": {
            var s = Strings()
            s.provider = "Fournisseur"
            s.usageRemaining = "Utilisation de l'IA restante : {0} %"
            s.unavailable = "Utilisation de l'IA indisponible"
            s.resets = "Réinitialisation : {0}"
            s.troubleshooting = "Ouvrir le guide de dépannage ›"
            s.refresh = "Actualiser"
            s.about = "À propos d'AI Meter"
            s.quit = "Quitter"
            s.version = "Version {0}"
            s.tagline = "Un outil open source de GuruHat"
            s.support = "Soutenir AI Meter"
            s.thanks = "Merci de soutenir ce projet\u{00A0}!"
            s.codexNoSignIn = "Aucune connexion Codex trouvée. Lancez codex et connectez-vous avec ChatGPT."
            s.codexExpired = "La connexion Codex a expiré. Lancez codex une fois pour la renouveler."
            s.claudeNoSignIn = "Aucune connexion Claude Code trouvée dans Terminal. Se connecter à l'app Claude ne suffit pas."
            s.claudeExpiredAt = "La connexion Claude a expiré à {0}. Lancez claude une fois dans Terminal pour la renouveler."
            s.claudeExpired = "La connexion Claude a expiré. Utilisez Claude Code une fois pour la renouveler."
            s.unreachable = "Impossible d'obtenir l'utilisation de {0}. Nouvel essai dans 5 minutes."
            s.rateLimited = "{0} limite les vérifications d'utilisation. Prochaine vérification à {1}."
            s.updateTitle = "{0} {1} est disponible"
            s.updateMessage = "Vous avez la version {0}. Télécharger la nouvelle version depuis GitHub ?"
            s.download = "Télécharger"
            s.later = "Plus tard"
            return s
        }(),
        "pt": {
            var s = Strings()
            s.provider = "Provedor"
            s.usageRemaining = "Uso de IA restante: {0}%"
            s.unavailable = "Uso de IA indisponível"
            s.resets = "Redefine: {0}"
            s.troubleshooting = "Abrir o guia de solução de problemas ›"
            s.refresh = "Atualizar"
            s.about = "Sobre o AI Meter"
            s.quit = "Sair"
            s.version = "Versão {0}"
            s.tagline = "Uma ferramenta de código aberto da GuruHat"
            s.support = "Apoiar o AI Meter"
            s.thanks = "Obrigado por apoiar este projeto!"
            s.codexNoSignIn = "Nenhum login do Codex encontrado. Execute codex e entre com o ChatGPT."
            s.codexExpired = "O login do Codex expirou. Execute codex uma vez para renová-lo."
            s.claudeNoSignIn = "Nenhum login do Claude Code encontrado no Terminal. Entrar no app do Claude não é suficiente."
            s.claudeExpiredAt = "O login do Claude expirou às {0}. Execute claude uma vez no Terminal para renová-lo."
            s.claudeExpired = "O login do Claude expirou. Use o Claude Code uma vez para renová-lo."
            s.unreachable = "Não foi possível obter o uso do {0}. Nova tentativa em 5 minutos."
            s.rateLimited = "O {0} está limitando as verificações de uso. Próxima verificação às {1}."
            s.updateTitle = "{0} {1} está disponível"
            s.updateMessage = "Você tem a versão {0}. Baixar a nova versão no GitHub?"
            s.download = "Baixar"
            s.later = "Mais tarde"
            return s
        }(),
        "ja": {
            var s = Strings()
            s.provider = "プロバイダ"
            s.usageRemaining = "AI の残り使用量: {0}%"
            s.unavailable = "AI 使用量を取得できません"
            s.resets = "リセット: {0}"
            s.troubleshooting = "トラブルシューティングガイドを開く ›"
            s.refresh = "更新"
            s.about = "AI Meter について"
            s.quit = "終了"
            s.version = "バージョン {0}"
            s.tagline = "GuruHat のオープンソースツール"
            s.support = "AI Meter を支援"
            s.thanks = "このプロジェクトを支援していただきありがとうございます！"
            s.codexNoSignIn = "Codex のサインインが見つかりません。codex を実行して ChatGPT でサインインしてください。"
            s.codexExpired = "Codex のサインインの有効期限が切れました。codex を一度実行して更新してください。"
            s.claudeNoSignIn = "ターミナルでの Claude Code のサインインが見つかりません。Claude アプリへのサインインだけでは使えません。"
            s.claudeExpiredAt = "Claude のサインインは {0} に期限切れになりました。ターミナルで claude を一度実行して更新してください。"
            s.claudeExpired = "Claude のサインインの有効期限が切れました。Claude Code を一度使用して更新してください。"
            s.unreachable = "{0} から使用状況を取得できませんでした。5 分後に再試行します。"
            s.rateLimited = "{0} が使用状況の確認を制限しています。次の確認は {1} です。"
            s.updateTitle = "{0} {1} が利用可能です"
            s.updateMessage = "現在のバージョンは {0} です。GitHub から新しいバージョンをダウンロードしますか?"
            s.download = "ダウンロード"
            s.later = "後で"
            return s
        }(),
        "zh-Hans": {
            var s = Strings()
            s.provider = "提供方"
            s.usageRemaining = "AI 剩余用量：{0}%"
            s.unavailable = "无法获取 AI 用量"
            s.resets = "重置时间：{0}"
            s.troubleshooting = "打开故障排除指南 ›"
            s.refresh = "刷新"
            s.about = "关于 AI Meter"
            s.quit = "退出"
            s.version = "版本 {0}"
            s.tagline = "GuruHat 开源工具"
            s.support = "支持 AI Meter"
            s.thanks = "感谢你对本项目的支持！"
            s.codexNoSignIn = "未找到 Codex 登录信息。请运行 codex 并使用 ChatGPT 登录。"
            s.codexExpired = "Codex 登录已过期。请运行一次 codex 以续期。"
            s.claudeNoSignIn = "未在“终端”中找到 Claude Code 登录信息。仅登录 Claude 应用是不够的。"
            s.claudeExpiredAt = "Claude 登录已于 {0} 过期。请在“终端”中运行一次 claude 以续期。"
            s.claudeExpired = "Claude 登录已过期。请使用一次 Claude Code 以续期。"
            s.unreachable = "无法从 {0} 获取用量。将在 5 分钟后重试。"
            s.rateLimited = "{0} 正在限制用量查询。下次查询时间：{1}。"
            s.updateTitle = "{0} {1} 现已推出"
            s.updateMessage = "你当前的版本是 {0}。要从 GitHub 下载新版本吗？"
            s.download = "下载"
            s.later = "稍后"
            return s
        }(),
        "ko": {
            var s = Strings()
            s.provider = "제공업체"
            s.usageRemaining = "남은 AI 사용량: {0}%"
            s.unavailable = "AI 사용량을 확인할 수 없음"
            s.resets = "초기화: {0}"
            s.troubleshooting = "문제 해결 가이드 열기 ›"
            s.refresh = "새로 고침"
            s.about = "AI Meter 정보"
            s.quit = "종료"
            s.version = "버전 {0}"
            s.tagline = "GuruHat 오픈 소스 도구"
            s.support = "AI Meter 후원하기"
            s.thanks = "이 프로젝트를 후원해 주셔서 감사합니다!"
            s.codexNoSignIn = "Codex 로그인 정보를 찾을 수 없습니다. codex를 실행하고 ChatGPT로 로그인하세요."
            s.codexExpired = "Codex 로그인이 만료되었습니다. codex를 한 번 실행하여 갱신하세요."
            s.claudeNoSignIn = "터미널에서 Claude Code 로그인 정보를 찾을 수 없습니다. Claude 앱에 로그인하는 것만으로는 충분하지 않습니다."
            s.claudeExpiredAt = "Claude 로그인이 {0}에 만료되었습니다. 터미널에서 claude를 한 번 실행하여 갱신하세요."
            s.claudeExpired = "Claude 로그인이 만료되었습니다. Claude Code를 한 번 사용하여 갱신하세요."
            s.unreachable = "{0}에서 사용량을 가져오지 못했습니다. 5분 후에 다시 시도합니다."
            s.rateLimited = "{0}에서 사용량 확인을 제한하고 있습니다. 다음 확인: {1}"
            s.updateTitle = "{0} {1} 업데이트가 있습니다"
            s.updateMessage = "현재 버전은 {0}입니다. GitHub에서 새 버전을 다운로드할까요?"
            s.download = "다운로드"
            s.later = "나중에"
            return s
        }(),
    ]
}
