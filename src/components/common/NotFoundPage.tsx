import React from 'react';
import { Link } from 'react-router-dom';
import './ErrorBoundary.css';

interface NotFoundPageProps {
  primaryTo: string;
  primaryLabel?: string;
}

const NotFoundPage: React.FC<NotFoundPageProps> = ({
  primaryTo,
  primaryLabel = 'Return to dashboard',
}) => (
  <section className="error-boundary-fallback" aria-labelledby="not-found-title">
    <div className="error-boundary-content">
      <h2 id="not-found-title">Page not found</h2>
      <p>The address may be outdated, or this page is not available for the current source.</p>
      <Link className="error-boundary-retry" to={primaryTo}>{primaryLabel}</Link>
    </div>
  </section>
);

export default NotFoundPage;
