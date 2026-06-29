import 'deployment_stack_config.dart';

/// Warns when a non-standard HTTPS host port breaks the default ACME TLS challenge.
class HttpsPortAcmeWarning {
  const HttpsPortAcmeWarning._();

  /// Whether [httpsHostPort] needs manual ACME changes for Let's Encrypt.
  static bool shouldWarn(int httpsHostPort) {
    return httpsHostPort != DeploymentStackConfig.defaultTraefikHttpsHostPort;
  }

  /// Lines shown after port prompts when [httpsHostPort] is not 443.
  static List<String> warningLines(int httpsHostPort) {
    return [
      'Let\'s Encrypt TLS challenge will not work with host port $httpsHostPort.',
      'Let\'s Encrypt validates on public port 443, not on your mapped host port.',
      '',
      'For a custom HTTPS port (for example when 443 is already in use), switch to',
      'Traefik DNS challenge with Cloudflare — same approach as a multi-stack VPS setup:',
      '',
      '1. In docker-compose.production.yaml, replace the TLS challenge:',
      '   - Remove: --certificatesresolvers.myresolver.acme.tlschallenge=true',
      '   - Add:',
      '     --certificatesresolvers.myresolver.acme.dnschallenge=true',
      '     --certificatesresolvers.myresolver.acme.dnschallenge.provider=cloudflare',
      '   - Add CF_DNS_API_TOKEN to the traefik service environment',
      '',
      '2. Add CF_DNS_API_TOKEN to your GitHub repository secrets',
      '',
      '3. Set SERVERPOD_*_PUBLIC_PORT to $httpsHostPort in deployment-docker.yml',
      '   (the generated workflow still defaults to 443)',
      '',
      '4. Set publicPort: $httpsHostPort in config/production.yaml for api,',
      '   insights, and web servers',
      '',
      '5. Use https://your-domain:$httpsHostPort/ in your client and OAuth redirect URIs',
      '',
      'Domains must be in Cloudflare for the DNS challenge to work.',
    ];
  }
}
