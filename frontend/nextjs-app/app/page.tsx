'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { fetchAuthHealth, fetchCircles, fetchMilestones, fetchPeople, fetchPermissions, fetchProjects, fetchRelationships, fetchSessionProfile, fetchTasks, fetchUsers, hasAuthSession, logout } from './lib/api';

export default function HomePage() {
  const [users, setUsers] = useState<any[]>([]);
  const [people, setPeople] = useState<any[]>([]);
  const [circles, setCircles] = useState<any[]>([]);
  const [relationships, setRelationships] = useState<any[]>([]);
  const [permissions, setPermissions] = useState<any[]>([]);
  const [projects, setProjects] = useState<any[]>([]);
  const [tasks, setTasks] = useState<any[]>([]);
  const [milestones, setMilestones] = useState<any[]>([]);
  const [sessionUser, setSessionUser] = useState<{ username: string; email: string } | null>(null);
  const [authHealth, setAuthHealth] = useState('checking...');
  const [sessionReady, setSessionReady] = useState(false);

  const workspaceTotal = useMemo(
    () => users.length + people.length + circles.length + projects.length + tasks.length + milestones.length,
    [users, people, circles, projects, tasks, milestones]
  );

  useEffect(() => {
    let isMounted = true;

    const loadLandingData = async () => {
      try {
        const health = await fetchAuthHealth();
        if (isMounted) {
          setAuthHealth(health);
        }
      } catch {
        if (isMounted) {
          setAuthHealth('unavailable');
        }
      }

      if (!hasAuthSession()) {
        if (isMounted) {
          setSessionReady(false);
        }
        return;
      }

      try {
        const profile = await fetchSessionProfile();
        const [usersData, peopleData, circlesData, relationshipsData, permissionsData, projectsData, tasksData, milestonesData] = await Promise.all([fetchUsers(), fetchPeople(), fetchCircles(), fetchRelationships(), fetchPermissions(), fetchProjects(), fetchTasks(), fetchMilestones()]);

        if (!isMounted) {
          return;
        }

        setSessionUser({ username: profile.username, email: profile.email });
        setUsers(usersData);
        setPeople(peopleData);
        setCircles(circlesData);
        setRelationships(relationshipsData);
        setPermissions(permissionsData);
        setProjects(projectsData);
        setTasks(tasksData);
        setMilestones(milestonesData);
        setSessionReady(true);
      } catch {
        if (!isMounted) {
          return;
        }

        setSessionReady(false);
        setSessionUser(null);
        setUsers([]);
        setPeople([]);
        setCircles([]);
        setRelationships([]);
        setPermissions([]);
        setProjects([]);
        setTasks([]);
        setMilestones([]);
      }
    };

    loadLandingData();

    return () => {
      isMounted = false;
    };
  }, []);

  const handleSignOut = async () => {
    await logout();
    setSessionReady(false);
    setSessionUser(null);
    setUsers([]);
    setPeople([]);
    setCircles([]);
    setRelationships([]);
    setPermissions([]);
    setProjects([]);
    setTasks([]);
    setMilestones([]);
  };

  return (
    <main className="container">
      <nav className="nav">
        <div style={{ fontWeight: 800 }}>MyAaptha</div>
        <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
          {sessionUser && (
            <span style={{ color: '#334155', fontSize: '0.9rem' }}>
              Signed in as {sessionUser.username}
            </span>
          )}
          {sessionReady ? (
            <button type="button" className="btn btn-secondary" onClick={handleSignOut}>Sign Out</button>
          ) : (
            <Link href="/auth">Sign In</Link>
          )}
          <Link href="/session">Session</Link>
          <Link href="/dashboard">Dashboard</Link>
        </div>
      </nav>

      <section className="hero">
        <div className="grid" style={{ gridTemplateColumns: '1.3fr 0.9fr' }}>
          <div className="card">
            <p style={{ color: '#2563eb', fontWeight: 700, marginBottom: 8 }}>Session-Aware Workspace</p>
            <h1 style={{ fontSize: '2.4rem', marginTop: 0 }}>Build the future of collaborative intelligence.</h1>
            <p style={{ color: '#64748b', lineHeight: 1.7 }}>
              Public landing is always available, while signed-in users get live workspace data immediately.
            </p>
            <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', marginTop: '1rem' }}>
              {sessionReady ? (
                <Link href="/dashboard" className="btn btn-primary">Open Dashboard</Link>
              ) : (
                <Link href="/auth" className="btn btn-primary">Sign In to Continue</Link>
              )}
              <Link href="/dashboard" className="btn btn-secondary">Go to Dashboard</Link>
            </div>
          </div>

          <div className="card">
            <h3>System status</h3>
            <ul>
              <li>Auth API: {authHealth}</li>
              <li>Session: {sessionReady ? 'active' : 'not signed in'}</li>
              <li>Workspace records loaded: {workspaceTotal}</li>
              <li>Relationships: {relationships.length}</li>
              <li>Permissions: {permissions.length}</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="grid" style={{ marginTop: '1.5rem', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
        <div className="card">
          <h3>Users</h3>
          {sessionReady ? (
            <ul>{users.slice(0, 3).map((user) => <li key={user.id || user.username}>{user.username || user.email}</li>)}</ul>
          ) : (
            <p style={{ color: '#64748b', marginBottom: 0 }}>Sign in to view user records.</p>
          )}
        </div>
        <div className="card">
          <h3>People</h3>
          {sessionReady ? (
            <ul>{people.slice(0, 3).map((person) => <li key={person.id || person.fullName}>{person.fullName || person.email}</li>)}</ul>
          ) : (
            <p style={{ color: '#64748b', marginBottom: 0 }}>Sign in to view people records.</p>
          )}
        </div>
        <div className="card">
          <h3>Circles</h3>
          {sessionReady ? (
            <ul>{circles.slice(0, 3).map((circle) => <li key={circle.id || circle.name}>{circle.name}</li>)}</ul>
          ) : (
            <p style={{ color: '#64748b', marginBottom: 0 }}>Sign in to view circle records.</p>
          )}
        </div>
        <div className="card">
          <h3>Relationships & Permissions</h3>
          <ul>
            <li>{relationships.length} relationships</li>
            <li>{permissions.length} permissions</li>
          </ul>
        </div>
        <div className="card">
          <h3>Projects</h3>
          {sessionReady ? (
            <ul>{projects.slice(0, 3).map((project) => <li key={project.id || project.name}>{project.name} • {project.status}</li>)}</ul>
          ) : (
            <p style={{ color: '#64748b', marginBottom: 0 }}>Sign in to view project records.</p>
          )}
        </div>
        <div className="card">
          <h3>Tasks</h3>
          {sessionReady ? (
            <ul>{tasks.slice(0, 3).map((task) => <li key={task.id || task.title}>{task.title} • {task.status}</li>)}</ul>
          ) : (
            <p style={{ color: '#64748b', marginBottom: 0 }}>Sign in to view task records.</p>
          )}
        </div>
        <div className="card">
          <h3>Milestones</h3>
          {sessionReady ? (
            <ul>{milestones.slice(0, 3).map((milestone) => <li key={milestone.id || milestone.name}>{milestone.name} • {milestone.status}</li>)}</ul>
          ) : (
            <p style={{ color: '#64748b', marginBottom: 0 }}>Sign in to view milestone records.</p>
          )}
        </div>
      </section>
    </main>
  );
}
