import clsx from 'clsx';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <p className="hero__subtitle" style={{fontStyle: 'italic', opacity: 0.85}}>Coming soon...</p>
        <div className={styles.buttons}>
          <a
            className="button button--secondary button--lg"
            href="/docs/intro">
            Get Started
          </a>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="jEAP - Java Enterprise Application Platform">
      <HomepageHeader />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              <div className="col col--4">
                <div className="text--center padding-horiz--md">
                  <Heading as="h3">Platform Libraries</Heading>
                  <p>
                    A set of shared libraries and Spring Boot starters that accelerate
                    the development of enterprise Java applications.
                  </p>
                </div>
              </div>
              <div className="col col--4">
                <div className="text--center padding-horiz--md">
                  <Heading as="h3">Best Practices</Heading>
                  <p>
                    Built-in support for messaging, security, monitoring, and
                    other cross-cutting concerns following proven patterns.
                  </p>
                </div>
              </div>
              <div className="col col--4">
                <div className="text--center padding-horiz--md">
                  <Heading as="h3">Cloud Native</Heading>
                  <p>
                    Designed for cloud-native deployments on multiple platforms,
                    supporting modern CI/CD workflows and observability.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
