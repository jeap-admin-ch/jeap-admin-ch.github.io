import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

// Font Awesome (existing icon font) — core + solid set only, used for the feature icons.
import '@fortawesome/fontawesome-free/css/fontawesome.min.css';
import '@fortawesome/fontawesome-free/css/solid.min.css';

import styles from './index.module.css';

// The six main parts / advantages of jEAP advertised on the landing page.
// Each links to the relevant documentation page.
const FEATURES = [
  {
    icon: 'fa-solid fa-layer-group',
    title: 'Solid Foundation',
    description:
      'Cross-cutting, non-functional concerns are solved once and standardized — a tested, maintained basis to build your applications on, so your team can focus on business logic.',
    to: '/docs/what-is-jeap',
  },
  {
    icon: 'fa-solid fa-cubes',
    title: 'Spring Boot Starters',
    description:
        'Drop-in auto-configuration for logging, monitoring, persistence, object storage, security, configuration management, secret management, encryption and more.',
    to: '/docs/building-blocks/spring-boot-starters',
  },
  {
    icon: 'fa-solid fa-shield-halved',
    title: 'Secure by Default',
    description:
      'OAuth2/OIDC resource-server security and client-side encryption of data-at-rest, e2e encryption for data-in-transit, ready to use.',
    to: '/docs/building-blocks/spring-boot-starters',
  },
  {
    icon: 'fa-solid fa-paper-plane',
    title: 'Event-Driven Messaging',
    description:
        'Support for Event-driven Architecture is a first class citizen in jEAP. Apache Kafka and Avro messaging with the Transactional Outbox and Sequential Inbox patterns built in, as well as compatibility checks enabling CI/CD.',
    to: '/docs/building-blocks/libraries',
  },
  {
    icon: 'fa-solid fa-server',
    title: 'Reusable Microservices',
    description:
      'Deploy ready-made service templates for error handling, process context & process archive, message exchange and more.',
    to: '/docs/building-blocks/reusable-microservices',
  },
  {
    icon: 'fa-solid fa-cloud',
    title: 'Open Source & Cloud Native',
    description:
      'Open Source - Apache 2.0 licensed. jEAP core is platform agnostic, with support for integrating with cloud-native platforms.',
    to: '/docs/building-blocks/tooling',
  },
];

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className="container">
        <img
          src="/img/logo.png"
          alt="jEAP logo"
          className={styles.heroLogo}
          width={200}
          height={200}
        />
        <Heading as="h1" className={styles.heroTitle}>
          {siteConfig.title}
        </Heading>
        <p className={styles.heroTagline}>{siteConfig.tagline}</p>
        <p className={styles.heroSubtitle}>
          A suite of Spring Boot libraries, starters and reusable microservices that solve
          the cross-functional concerns of enterprise applications — so your team can focus
          on business logic.
        </p>
        <div className={styles.buttons}>
          <Link className="button button--primary button--lg" to="/docs/what-is-jeap">
            Get Started
          </Link>
          <Link
            className="button button--secondary button--lg"
            to="https://github.com/jeap-admin-ch">
            View on GitHub
          </Link>
        </div>
      </div>
    </header>
  );
}

function Feature({icon, title, description, to}) {
  return (
    <div className={clsx('col col--4', styles.featureCol)}>
      <Link to={to} className={styles.featureCard}>
        <span className={styles.featureIcon}>
          <i className={icon} aria-hidden="true"></i>
        </span>
        <Heading as="h3" className={styles.featureTitle}>
          {title}
        </Heading>
        <p className={styles.featureDescription}>{description}</p>
      </Link>
    </div>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="jEAP — Java Enterprise Application Platform: Spring Boot libraries, starters and reusable microservices for enterprise applications.">
      <HomepageHeader />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              {FEATURES.map((feature) => (
                <Feature key={feature.title} {...feature} />
              ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
