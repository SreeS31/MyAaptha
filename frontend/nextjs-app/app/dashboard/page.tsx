'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { bulkUpdateMilestoneStatus, createCircle, createMilestone, createPerson, createProject, createRelationship, createTask, createTaskGroup, createUser, deleteMilestone, fetchCircles, fetchDashboardSummary, fetchMilestones, fetchPeople, fetchPermissions, fetchProjects, fetchRelationships, fetchSessionProfile, fetchTaskGroups, fetchTasks, fetchUsers, hasAuthSession, isUnauthorizedError, logout, updateCircle, updateMilestone, updatePermission, updatePerson, updateProject, updateRelationship, updateTask, updateUser } from '../lib/api';
import UserNetworkDashboard from './UserNetworkDashboard';

type ResourceType = 'user' | 'person' | 'circle' | 'project' | 'task' | 'milestone';
type ToastTone = 'success' | 'error';
const supportedRelationshipTypes=['Mother','Father','Wife','Husband','Son','Daughter','Brother','Sister','Grandmother','Grandfather','Granddaughter','Grandson','Aunt','Uncle','Niece','Nephew','Cousin','Guardian','Relative','Friend','Colleague','Other'];

export default function DashboardPage() {
  const router = useRouter();
  const [users, setUsers] = useState<any[]>([]);
  const [people, setPeople] = useState<any[]>([]);
  const [circles, setCircles] = useState<any[]>([]);
  const [relationships, setRelationships] = useState<any[]>([]);
  const [permissions, setPermissions] = useState<any[]>([]);
  const [projects, setProjects] = useState<any[]>([]);
  const [tasks, setTasks] = useState<any[]>([]);
  const [taskGroups, setTaskGroups] = useState<any[]>([]);
  const [milestones, setMilestones] = useState<any[]>([]);
  const [sessionUser, setSessionUser] = useState<{ username: string; email: string; role: string } | null>(null);
  const [sessionLoading, setSessionLoading] = useState(true);
  const [sessionError, setSessionError] = useState('');
  const [resourceType, setResourceType] = useState<ResourceType>('user');
  const [summary, setSummary] = useState({ userCount: 0, personCount: 0, circleCount: 0, relationshipCount: 0, permissionCount: 0 });
  const [status, setStatus] = useState('Ready to add a new record.');
  const [toast, setToast] = useState<{ id: number; message: string; tone: ToastTone } | null>(null);
  const [editingMilestoneId, setEditingMilestoneId] = useState<number | null>(null);
  const [milestoneActionPendingId, setMilestoneActionPendingId] = useState<number | null>(null);
  const [roadmapProjectFilter, setRoadmapProjectFilter] = useState('all');
  const [roadmapStatusFilter, setRoadmapStatusFilter] = useState('all');
  const [roadmapSort, setRoadmapSort] = useState('status-priority');
  const [roadmapQuery, setRoadmapQuery] = useState('');
  const [selectedMilestoneIds, setSelectedMilestoneIds] = useState<number[]>([]);
  const [bulkStatusPending, setBulkStatusPending] = useState(false);
  const [milestoneEditState, setMilestoneEditState] = useState({
    name: '',
    description: '',
    status: 'Planned',
    projectId: '',
    dueDate: '',
    blockedReason: '',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formState, setFormState] = useState({
    username: '',
    email: '',
    phoneNumber: '',
    password: '',
    fullName: '',
    personGender: 'Unspecified',
    circleName: '',
    description: '',
    projectName: '',
    projectStatus: 'Active',
    taskTitle: '',
    taskDetails: '',
    taskStatus: 'Todo',
    taskProjectId: '',
    taskMilestoneId: '',
    milestoneName: '',
    milestoneDescription: '',
    milestoneStatus: 'Planned',
    milestoneProjectId: '',
    milestoneDueDate: '',
    milestoneBlockedReason: '',
  });

  const loadData = useCallback(async () => {
    setSessionLoading(true);
    setSessionError('');
    try {
      const profileData = await fetchSessionProfile();
      setSessionUser({ username: profileData.username, email: profileData.email, role: profileData.role });
      if (profileData.role !== 'ADMIN') return;
      const [usersData, peopleData, circlesData, relationshipsData, permissionsData, projectsData, tasksData, taskGroupsData, milestonesData, summaryData] = await Promise.all([fetchUsers(), fetchPeople(), fetchCircles(), fetchRelationships(), fetchPermissions(), fetchProjects(), fetchTasks(), fetchTaskGroups(), fetchMilestones(), fetchDashboardSummary()]);
        setUsers(usersData);
        setPeople(peopleData);
        setCircles(circlesData);
        setRelationships(relationshipsData);
        setPermissions(permissionsData);
        setProjects(projectsData);
        setTasks(tasksData);
        setTaskGroups(taskGroupsData);
        setMilestones(milestonesData);
        setSummary(summaryData);
    } catch (error) {
      if (isUnauthorizedError(error)) {
        router.replace('/auth?reason=session-expired');
        return;
      }

      setSessionError(error instanceof Error ? error.message : 'The dashboard could not reach the server.');

      setUsers([]);
      setPeople([]);
      setCircles([]);
      setRelationships([]);
      setPermissions([]);
      setProjects([]);
      setTasks([]);
      setTaskGroups([]);
      setMilestones([]);
      setSessionUser(null);
      setSummary({ userCount: 0, personCount: 0, circleCount: 0, relationshipCount: 0, permissionCount: 0 });
    } finally {
      setSessionLoading(false);
    }
  }, [router]);

  useEffect(() => {
    if (!hasAuthSession()) {
      router.replace('/auth');
      return;
    }

    loadData();
  }, [loadData, router]);

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      setToast((currentToast) => (currentToast?.id === toast.id ? null : currentToast));
    }, 3200);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [toast]);

  useEffect(() => {
    setSelectedMilestoneIds((currentIds) => currentIds.filter((id) => milestones.some((milestone) => milestone.id === id)));
  }, [milestones]);

  const showToast = (message: string, tone: ToastTone) => {
    setToast({ id: Date.now(), message, tone });
  };

  const todayIsoDate = new Date().toISOString().slice(0, 10);

  const isMilestoneOverdue = (milestone: any) => (
    !!milestone.dueDate && milestone.dueDate < todayIsoDate && milestone.status !== 'Completed'
  );

  const getMilestoneProgress = (milestoneId: number) => {
    const linkedTasks = tasks.filter((task) => task.milestoneId === milestoneId);
    const completedTasks = linkedTasks.filter((task) => task.status === 'Done');
    const totalTasks = linkedTasks.length;
    const percent = totalTasks === 0 ? 0 : Math.round((completedTasks.length / totalTasks) * 100);

    return { totalTasks, completedTasks: completedTasks.length, percent };
  };

  const getBlockedRank = (milestone: any) => {
    if (milestone.status !== 'Blocked') {
      return 2;
    }

    return milestone.blockedReason && String(milestone.blockedReason).trim().length > 0 ? 0 : 1;
  };

  const filteredRoadmapMilestones = milestones.filter((milestone) => {
    const matchesProject = roadmapProjectFilter === 'all' || String(milestone.projectId) === roadmapProjectFilter;
    const matchesStatus = roadmapStatusFilter === 'all' || milestone.status === roadmapStatusFilter;
    const query = roadmapQuery.trim().toLowerCase();
    const matchesQuery =
      query.length === 0 ||
      String(milestone.name || '').toLowerCase().includes(query) ||
      String(milestone.description || '').toLowerCase().includes(query);

    return matchesProject && matchesStatus && matchesQuery;
  });

  const sortedRoadmapMilestones = [...filteredRoadmapMilestones].sort((a, b) => {
    if (roadmapSort === 'least-progress-first') {
      const progressA = getMilestoneProgress(a.id).percent;
      const progressB = getMilestoneProgress(b.id).percent;
      if (progressA !== progressB) {
        return progressA - progressB;
      }
      return String(a.name || '').localeCompare(String(b.name || ''));
    }

    if (roadmapSort === 'most-blocked-first') {
      const blockedRankA = getBlockedRank(a);
      const blockedRankB = getBlockedRank(b);
      if (blockedRankA !== blockedRankB) {
        return blockedRankA - blockedRankB;
      }

      const dueDateA = String(a.dueDate || '9999-12-31');
      const dueDateB = String(b.dueDate || '9999-12-31');
      if (dueDateA !== dueDateB) {
        return dueDateA.localeCompare(dueDateB);
      }

      const progressA = getMilestoneProgress(a.id).percent;
      const progressB = getMilestoneProgress(b.id).percent;
      if (progressA !== progressB) {
        return progressA - progressB;
      }

      return String(a.name || '').localeCompare(String(b.name || ''));
    }

    const statusOrder: Record<string, number> = {
      Blocked: 0,
      'In Progress': 1,
      Planned: 2,
      Completed: 3,
    };
    const statusA = statusOrder[a.status] ?? 99;
    const statusB = statusOrder[b.status] ?? 99;
    if (statusA !== statusB) {
      return statusA - statusB;
    }

    const dueDateA = String(a.dueDate || '9999-12-31');
    const dueDateB = String(b.dueDate || '9999-12-31');
    if (dueDateA !== dueDateB) {
      return dueDateA.localeCompare(dueDateB);
    }

    return String(a.name || '').localeCompare(String(b.name || ''));
  });

  const visibleMilestoneIds = sortedRoadmapMilestones
    .map((milestone) => Number(milestone.id))
    .filter((id) => !Number.isNaN(id));
  const allVisibleSelected = visibleMilestoneIds.length > 0 && visibleMilestoneIds.every((id) => selectedMilestoneIds.includes(id));

  const toggleMilestoneSelection = (milestoneId: number) => {
    setSelectedMilestoneIds((currentIds) => (
      currentIds.includes(milestoneId)
        ? currentIds.filter((id) => id !== milestoneId)
        : [...currentIds, milestoneId]
    ));
  };

  const toggleSelectAllVisible = () => {
    setSelectedMilestoneIds((currentIds) => {
      if (allVisibleSelected) {
        return currentIds.filter((id) => !visibleMilestoneIds.includes(id));
      }

      const mergedIds = new Set([...currentIds, ...visibleMilestoneIds]);
      return Array.from(mergedIds);
    });
  };

  const startMilestoneEdit = (milestone: any) => {
    setEditingMilestoneId(milestone.id);
    setMilestoneEditState({
      name: milestone.name || '',
      description: milestone.description || '',
      status: milestone.status || 'Planned',
      projectId: milestone.projectId ? String(milestone.projectId) : '',
      dueDate: milestone.dueDate || '',
      blockedReason: milestone.blockedReason || '',
    });
  };

  const cancelMilestoneEdit = () => {
    setEditingMilestoneId(null);
    setMilestoneEditState({
      name: '',
      description: '',
      status: 'Planned',
      projectId: '',
      dueDate: '',
      blockedReason: '',
    });
  };

  const handleMilestoneSave = async (milestoneId: number) => {
    if (milestoneEditState.status === 'Blocked' && milestoneEditState.blockedReason.trim().length === 0) {
      const message = 'Blocked milestones require a reason.';
      setStatus(message);
      showToast(message, 'error');
      return;
    }

    const previousMilestones = milestones;
    const optimisticProjectId = milestoneEditState.projectId ? Number(milestoneEditState.projectId) : undefined;
    const optimisticDueDate = milestoneEditState.dueDate || undefined;
    const optimisticBlockedReason = milestoneEditState.status === 'Blocked'
      ? (milestoneEditState.blockedReason.trim() || undefined)
      : undefined;

    setMilestones((currentMilestones) => currentMilestones.map((milestone) => (
      milestone.id === milestoneId
        ? {
            ...milestone,
            name: milestoneEditState.name,
            description: milestoneEditState.description,
            status: milestoneEditState.status,
            projectId: optimisticProjectId,
            dueDate: optimisticDueDate,
            blockedReason: optimisticBlockedReason,
          }
        : milestone
    )));
    setStatus('Updating milestone...');
    cancelMilestoneEdit();
    setMilestoneActionPendingId(milestoneId);
    try {
      await updateMilestone(milestoneId, {
        name: milestoneEditState.name,
        description: milestoneEditState.description,
        status: milestoneEditState.status,
        projectId: optimisticProjectId,
        dueDate: optimisticDueDate,
        blockedReason: optimisticBlockedReason,
      });
      const successMessage = 'Milestone updated successfully.';
      setStatus(successMessage);
      showToast(successMessage, 'success');
    } catch {
      setMilestones(previousMilestones);
      const errorMessage = 'Failed to update milestone. Check the API and try again.';
      setStatus(errorMessage);
      showToast(errorMessage, 'error');
    } finally {
      setMilestoneActionPendingId(null);
    }
  };

  const handleMilestoneDelete = async (milestoneId: number) => {
    const milestoneToDelete = milestones.find((milestone) => milestone.id === milestoneId);
    const shouldDelete = window.confirm(`Delete milestone "${milestoneToDelete?.name || 'this milestone'}"? This action cannot be undone.`);

    if (!shouldDelete) {
      return;
    }

    const previousMilestones = milestones;
    const previousTasks = tasks;

    setMilestones((currentMilestones) => currentMilestones.filter((milestone) => milestone.id !== milestoneId));
    setTasks((currentTasks) => currentTasks.map((task) => (
      task.milestoneId === milestoneId ? { ...task, milestoneId: undefined } : task
    )));
    setStatus('Deleting milestone...');

    if (editingMilestoneId === milestoneId) {
      cancelMilestoneEdit();
    }

    setMilestoneActionPendingId(milestoneId);
    try {
      await deleteMilestone(milestoneId);
      const successMessage = 'Milestone deleted successfully.';
      setStatus(successMessage);
      showToast(successMessage, 'success');
    } catch {
      setMilestones(previousMilestones);
      setTasks(previousTasks);
      const errorMessage = 'Failed to delete milestone. Check linked records and try again.';
      setStatus(errorMessage);
      showToast(errorMessage, 'error');
    } finally {
      setMilestoneActionPendingId(null);
    }
  };

  const handleMilestoneQuickStatus = async (milestoneId: number, nextStatus: string) => {
    const blockedReason = nextStatus === 'Blocked'
      ? window.prompt('Enter a blocked reason for this milestone:')?.trim()
      : undefined;

    if (nextStatus === 'Blocked' && !blockedReason) {
      const message = 'Blocked milestones require a reason.';
      setStatus(message);
      showToast(message, 'error');
      return;
    }

    const previousMilestones = milestones;
    setMilestones((currentMilestones) => currentMilestones.map((milestone) => (
      milestone.id === milestoneId
        ? {
            ...milestone,
            status: nextStatus,
            blockedReason: nextStatus === 'Blocked' ? blockedReason : undefined,
          }
        : milestone
    )));
    setMilestoneActionPendingId(milestoneId);

    try {
      const milestoneToUpdate = previousMilestones.find((milestone) => milestone.id === milestoneId);
      if (!milestoneToUpdate) {
        throw new Error('Milestone not found');
      }

      await updateMilestone(milestoneId, {
        name: milestoneToUpdate.name,
        description: milestoneToUpdate.description,
        projectId: milestoneToUpdate.projectId,
        dueDate: milestoneToUpdate.dueDate,
        blockedReason: nextStatus === 'Blocked' ? blockedReason : undefined,
        status: nextStatus,
      });

      const successMessage = `Milestone moved to ${nextStatus}.`;
      setStatus(successMessage);
      showToast(successMessage, 'success');
    } catch {
      setMilestones(previousMilestones);
      const errorMessage = 'Failed to update milestone status. Please try again.';
      setStatus(errorMessage);
      showToast(errorMessage, 'error');
    } finally {
      setMilestoneActionPendingId(null);
    }
  };

  const handleBulkMilestoneStatus = async (nextStatus: string) => {
    if (selectedMilestoneIds.length === 0) {
      const infoMessage = 'Select at least one milestone to run bulk actions.';
      setStatus(infoMessage);
      showToast(infoMessage, 'error');
      return;
    }

    const blockedReason = nextStatus === 'Blocked'
      ? window.prompt('Enter a reason for blocking selected milestones:')?.trim()
      : undefined;

    if (nextStatus === 'Blocked' && !blockedReason) {
      const message = 'Blocked milestones require a reason.';
      setStatus(message);
      showToast(message, 'error');
      return;
    }

    const previousMilestones = milestones;
    setMilestones((currentMilestones) => currentMilestones.map((milestone) => (
      selectedMilestoneIds.includes(milestone.id)
        ? {
            ...milestone,
            status: nextStatus,
            blockedReason: nextStatus === 'Blocked' ? blockedReason : undefined,
          }
        : milestone
    )));
    setBulkStatusPending(true);

    try {
      await bulkUpdateMilestoneStatus(selectedMilestoneIds, nextStatus, blockedReason);
      const successMessage = `Updated ${selectedMilestoneIds.length} milestone(s) to ${nextStatus}.`;
      setStatus(successMessage);
      showToast(successMessage, 'success');
      setSelectedMilestoneIds([]);
    } catch {
      setMilestones(previousMilestones);
      const errorMessage = 'Bulk status update failed. Please try again.';
      setStatus(errorMessage);
      showToast(errorMessage, 'error');
    } finally {
      setBulkStatusPending(false);
    }
  };

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setIsSubmitting(true);
    setStatus('Creating record...');

    try {
      if (resourceType === 'user') {
        await createUser({
          username: formState.username,
          email: formState.email,
          phoneNumber: formState.phoneNumber,
          password: formState.password,
        });
      } else if (resourceType === 'person') {
        await createPerson({
          fullName: formState.fullName,
          email: formState.email,
          gender: formState.personGender,
        });
      } else if (resourceType === 'circle') {
        await createCircle({
          name: formState.circleName,
          description: formState.description,
        });
      } else {
        if (resourceType === 'project') {
          await createProject({
            name: formState.projectName,
            description: formState.description,
            status: formState.projectStatus,
          });
        } else if (resourceType === 'task') {
          await createTask({
            title: formState.taskTitle,
            details: formState.taskDetails,
            status: formState.taskStatus,
            projectId: formState.taskProjectId ? Number(formState.taskProjectId) : undefined,
            milestoneId: formState.taskMilestoneId ? Number(formState.taskMilestoneId) : undefined,
          });
        } else {
          const blockedReason = formState.milestoneStatus === 'Blocked'
            ? formState.milestoneBlockedReason.trim()
            : '';
          if (formState.milestoneStatus === 'Blocked' && blockedReason.length === 0) {
            throw new Error('blocked-reason-required');
          }

          await createMilestone({
            name: formState.milestoneName,
            description: formState.milestoneDescription,
            status: formState.milestoneStatus,
            projectId: formState.milestoneProjectId ? Number(formState.milestoneProjectId) : undefined,
            dueDate: formState.milestoneDueDate || undefined,
            blockedReason: blockedReason || undefined,
          });
        }
      }

      const successMessage = `Created ${resourceType} successfully.`;
      setStatus(successMessage);
      showToast(successMessage, 'success');
      setFormState({
        username: '',
        email: '',
        phoneNumber: '',
        password: '',
        fullName: '',
        personGender: 'Unspecified',
        circleName: '',
        description: '',
        projectName: '',
        projectStatus: 'Active',
        taskTitle: '',
        taskDetails: '',
        taskStatus: 'Todo',
        taskProjectId: '',
        taskMilestoneId: '',
        milestoneName: '',
        milestoneDescription: '',
        milestoneStatus: 'Planned',
        milestoneProjectId: '',
        milestoneDueDate: '',
        milestoneBlockedReason: '',
      });
      loadData();
    } catch (error) {
      const errorMessage = error instanceof Error && error.message === 'blocked-reason-required'
        ? 'Blocked milestones require a reason.'
        : isUnauthorizedError(error)
          ? 'Your session expired. Please sign in again.'
          : error instanceof Error
            ? `Could not create ${resourceType}: ${error.message}`
            : 'Failed to create the record. Check the API and try again.';
      setStatus(errorMessage);
      showToast(errorMessage, 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleLogout = async () => {
    await logout();
    router.replace('/auth');
  };

  const promptValue = (label: string, currentValue = '') => window.prompt(label, currentValue);

  const handleAdminCreate = async (kind: 'relationship' | 'task group') => {
    if (sessionUser?.role !== 'ADMIN') return;
    const name = window.prompt(kind === 'relationship' ? 'Relationship type' : 'Task group name');
    if (!name) return;
    try {
      if (kind === 'relationship') await createRelationship({ type: name });
      else {
        const description = window.prompt('Task group description') || '';
        await createTaskGroup({ name, description });
      }
      await loadData();
      showToast(`${kind} created successfully.`, 'success');
    } catch (error) { showToast(error instanceof Error ? error.message : `Could not create ${kind}.`, 'error'); }
  };

  const handleAdminEdit = async (recordType: 'user' | 'person' | 'circle' | 'relationship' | 'permission' | 'project' | 'task', record: any) => {
    try {
      if (sessionUser?.role !== 'ADMIN') {
        throw new Error('Administrator access is required to edit records.');
      }
      if (!record.id) {
        throw new Error('This record cannot be edited because it has no identifier.');
      }

      if (recordType === 'user') {
        const username = promptValue('Username', record.username);
        const phoneNumber = promptValue('Mobile number', record.phoneNumber);
        const email = promptValue('Email (optional)', record.email || '');
        const password = promptValue('New password (leave blank to keep current password)', '');
        if (username === null || phoneNumber === null || email === null || password === null) return;
        await updateUser(record.id, { username, phoneNumber, email: email || undefined, password: password || undefined });
      } else if (recordType === 'person') {
        const fullName = promptValue('Full name', record.fullName);
        const email = promptValue('Email', record.email);
        const gender = promptValue('Gender', record.gender || 'Unspecified');
        if (fullName === null || email === null || gender === null) return;
        await updatePerson(record.id, { fullName, email, gender });
      } else if (recordType === 'circle') {
        const name = promptValue('Circle name', record.name);
        const description = promptValue('Description', record.description);
        if (name === null || description === null) return;
        await updateCircle(record.id, { name, description });
      } else if (recordType === 'relationship') {
        const type = promptValue('Relationship type', record.type);
        if (type === null) return;
        await updateRelationship(record.id, { type });
      } else if (recordType === 'permission') {
        const name = promptValue('Permission name', record.name);
        const description = promptValue('Description', record.description);
        if (name === null || description === null) return;
        await updatePermission(record.id, { name, description });
      } else if (recordType === 'project') {
        const name = promptValue('Project name', record.name);
        const description = promptValue('Description', record.description);
        const status = promptValue('Status: Active, Planning, or Completed', record.status);
        if (name === null || description === null || status === null) return;
        await updateProject(record.id, { name, description, status });
      } else {
        const title = promptValue('Task title', record.title);
        const details = promptValue('Task details', record.details);
        const status = promptValue('Status: Todo, In Progress, or Done', record.status);
        if (title === null || details === null || status === null) return;
        await updateTask(record.id, { title, details, status, projectId: record.projectId || undefined, milestoneId: record.milestoneId || undefined });
      }

      const message = `${recordType} updated successfully.`;
      setStatus(message);
      showToast(message, 'success');
      await loadData();
    } catch (error) {
      const message = error instanceof Error ? `Could not update ${recordType}: ${error.message}` : `Could not update ${recordType}.`;
      setStatus(message);
      showToast(message, 'error');
    }
  };

  const taskStatusCounts = {
    todo: tasks.filter((task) => task.status === 'Todo').length,
    inProgress: tasks.filter((task) => task.status === 'In Progress').length,
    done: tasks.filter((task) => task.status === 'Done').length,
  };
  const taskTotal = tasks.length;
  const completionRate = taskTotal === 0 ? 0 : Math.round((taskStatusCounts.done / taskTotal) * 100);
  const chartMaximum = Math.max(taskStatusCounts.todo, taskStatusCounts.inProgress, taskStatusCounts.done, 1);
  const activeMilestones = milestones.filter((milestone) => milestone.status !== 'Completed').length;

  if (sessionUser?.role !== 'ADMIN') {
    if (sessionUser) return <UserNetworkDashboard username={sessionUser.username} />;
    if (sessionLoading) return <main className="container"><p>Loading your network…</p></main>;
    return <main className="container"><section className="card social-empty"><h2>Dashboard could not load</h2><p>{sessionError || 'Your session is no longer available.'}</p><div><button className="btn btn-primary" onClick={()=>void loadData()}>Try again</button><button className="btn btn-secondary" onClick={()=>router.replace('/auth')}>Sign in again</button></div></section></main>;
  }

  return (
    <main className="container" style={{ paddingTop: '3rem' }}>
      {toast && (
        <div className={`toast toast-${toast.tone}`} role="status" aria-live="polite">
          <p style={{ margin: 0 }}>{toast.message}</p>
          <button
            type="button"
            className="toast-dismiss"
            onClick={() => setToast(null)}
            aria-label="Dismiss notification"
          >
            Close
          </button>
        </div>
      )}

      <div className="nav">
        <div style={{ fontWeight: 800 }}>Dashboard</div>
        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
          {sessionUser && <span style={{ color: '#334155', fontSize: '0.9rem' }}>Signed in as {sessionUser.username}</span>}
          <Link href="/">Back home</Link>
          <Link href="/session">Session</Link>
          <Link href="/moderation">Moderation</Link>
          <button type="button" className="btn" onClick={handleLogout}>Sign out</button>
        </div>
      </div>

      <section className="dashboard-welcome">
        <div>
          <p className="eyebrow">MYAAPTHA OVERVIEW</p>
          <h1>Good to see you{sessionUser ? `, ${sessionUser.username}` : ''}.</h1>
          <p>See your circles, people, and project work at a glance.</p>
        </div>
        <div className="welcome-orbit" aria-hidden="true"><span /><span /><span /></div>
      </section>

      <section className="metric-grid">
        <div className="summary-card metric-purple"><div><p className="summary-label">Users</p><h2 className="summary-value">{summary.userCount}</h2><p className="summary-meta">Signed-in accounts</p></div><div className="summary-icon">U</div></div>
        <div className="summary-card metric-pink"><div><p className="summary-label">People</p><h2 className="summary-value">{summary.personCount}</h2><p className="summary-meta">Profiles in the network</p></div><div className="summary-icon">P</div></div>
        <div className="summary-card metric-mint"><div><p className="summary-label">Circles</p><h2 className="summary-value">{summary.circleCount}</h2><p className="summary-meta">Active communities</p></div><div className="summary-icon">C</div></div>
        <div className="summary-card metric-amber"><div><p className="summary-label">Relationships</p><h2 className="summary-value">{summary.relationshipCount}</h2><p className="summary-meta">Connections tracked</p></div><div className="summary-icon">R</div></div>
        <div className="summary-card metric-sky"><div><p className="summary-label">Tasks complete</p><h2 className="summary-value">{completionRate}%</h2><p className="summary-meta">{taskStatusCounts.done} of {taskTotal} tasks done</p></div><div className="summary-icon">✓</div></div>
      </section>

      <section className="analytics-grid">
        <article className="analytics-card task-chart-card">
          <div className="chart-heading"><div><p className="eyebrow">WORKFLOW</p><h2>Task momentum</h2></div><span className="chart-badge">{taskTotal} total</span></div>
          <div className="bar-chart" role="img" aria-label={`Tasks: ${taskStatusCounts.todo} to do, ${taskStatusCounts.inProgress} in progress, and ${taskStatusCounts.done} done`}>
            {[{ label: 'To do', value: taskStatusCounts.todo, tone: 'bar-lilac' }, { label: 'Working', value: taskStatusCounts.inProgress, tone: 'bar-peach' }, { label: 'Done', value: taskStatusCounts.done, tone: 'bar-mint' }].map((item) => <div className="bar-column" key={item.label}><span className="bar-value">{item.value}</span><div className="bar-track"><span className={`bar-fill ${item.tone}`} style={{ height: `${Math.max((item.value / chartMaximum) * 100, item.value ? 12 : 0)}%` }} /></div><span className="bar-label">{item.label}</span></div>)}
          </div>
        </article>
        <article className="analytics-card progress-chart-card">
          <div className="chart-heading"><div><p className="eyebrow">DELIVERY</p><h2>Completion</h2></div><span className="chart-badge">Live</span></div>
          <div className="donut-layout"><div className="donut-chart" style={{ background: `conic-gradient(#6ed0ad 0 ${completionRate}%, #edf0f7 ${completionRate}% 100%)` }}><div><strong>{completionRate}%</strong><span>done</span></div></div><div className="chart-legend"><p><i className="legend-dot dot-mint" />Done <b>{taskStatusCounts.done}</b></p><p><i className="legend-dot dot-peach" />In progress <b>{taskStatusCounts.inProgress}</b></p><p><i className="legend-dot dot-lilac" />To do <b>{taskStatusCounts.todo}</b></p></div></div>
        </article>
        <article className="analytics-card network-chart-card">
          <div className="chart-heading"><div><p className="eyebrow">CONNECTIONS</p><h2>Circle network</h2></div><span className="chart-badge">{summary.relationshipCount} links</span></div>
          <div className="network-visual" role="img" aria-label={`${summary.personCount} people, ${summary.circleCount} circles, and ${summary.relationshipCount} relationships`}><span className="network-link link-one" /><span className="network-link link-two" /><span className="network-link link-three" /><span className="network-node node-center">{summary.personCount}</span><span className="network-node node-pink">P</span><span className="network-node node-blue">C</span><span className="network-node node-yellow">R</span></div>
          <p className="network-caption"><b>{summary.personCount}</b> people connected through <b>{summary.circleCount}</b> circles.</p>
        </article>
        <article className="analytics-card milestone-chart-card">
          <div className="chart-heading"><div><p className="eyebrow">ROADMAP</p><h2>Milestone focus</h2></div><span className="chart-badge">{activeMilestones} active</span></div>
          <div className="milestone-visual"><div className="milestone-wave"><span /><span /><span /><span /><span /></div><div className="milestone-stat"><strong>{milestones.length}</strong><span>Milestones</span></div></div>
          <p className="network-caption">Keep the next milestone moving with clear, visible progress.</p>
        </article>
      </section>

      <section className="grid legacy-summary" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', marginTop: '1rem' }}>
        <div className="summary-card">
          <div>
            <p className="summary-label">Users</p>
            <h2 className="summary-value">{summary.userCount}</h2>
            <p className="summary-meta">Signed-in accounts</p>
          </div>
          <div className="summary-icon">👤</div>
        </div>
        <div className="summary-card">
          <div>
            <p className="summary-label">People</p>
            <h2 className="summary-value">{summary.personCount}</h2>
            <p className="summary-meta">Profiles in the network</p>
          </div>
          <div className="summary-icon">🧑‍🤝‍🧑</div>
        </div>
        <div className="summary-card">
          <div>
            <p className="summary-label">Circles</p>
            <h2 className="summary-value">{summary.circleCount}</h2>
            <p className="summary-meta">Active communities</p>
          </div>
          <div className="summary-icon">🔗</div>
        </div>
        <div className="summary-card">
          <div>
            <p className="summary-label">Relationships</p>
            <h2 className="summary-value">{summary.relationshipCount}</h2>
            <p className="summary-meta">Connections tracked</p>
          </div>
          <div className="summary-icon">🤝</div>
        </div>
        <div className="summary-card">
          <div>
            <p className="summary-label">Permissions</p>
            <h2 className="summary-value">{summary.permissionCount}</h2>
            <p className="summary-meta">Access rules defined</p>
          </div>
          <div className="summary-icon">🔐</div>
        </div>
      </section>

      <section className="card" style={{ marginTop: '1.5rem' }}>
        <h3>Create a new record</h3>
        <p style={{ color: '#64748b' }}>
          Use this form to post users, people, circles, projects, and tasks directly to the backend API.
        </p>
        <form onSubmit={handleSubmit} style={{ display: 'grid', gap: '0.9rem', marginTop: '1rem' }}>
          <label style={{ display: 'grid', gap: '0.35rem' }}>
            <span>Record type</span>
            <select
              value={resourceType}
              onChange={(event) => setResourceType(event.target.value as ResourceType)}
              style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
            >
              <option value="user">User</option>
              <option value="person">Person</option>
              <option value="circle">Circle</option>
              <option value="project">Project</option>
              <option value="task">Task</option>
              <option value="milestone">Milestone</option>
            </select>
          </label>

          {resourceType === 'user' && (
            <>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Username</span>
                <input
                  required
                  value={formState.username}
                  onChange={(event) => setFormState({ ...formState, username: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Mobile number</span>
                <input
                  required
                  type="tel"
                  value={formState.phoneNumber}
                  onChange={(event) => setFormState({ ...formState, phoneNumber: event.target.value })}
                  placeholder="+15551234567"
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Email (optional)</span>
                <input
                  type="email"
                  value={formState.email}
                  onChange={(event) => setFormState({ ...formState, email: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Password</span>
                <input
                  required
                  type="password"
                  value={formState.password}
                  onChange={(event) => setFormState({ ...formState, password: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
            </>
          )}

          {resourceType === 'person' && (
            <>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Full name</span>
                <input
                  required
                  value={formState.fullName}
                  onChange={(event) => setFormState({ ...formState, fullName: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Email</span>
                <input
                  required
                  type="email"
                  value={formState.email}
                  onChange={(event) => setFormState({ ...formState, email: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Gender</span>
                <select value={formState.personGender} onChange={(event) => setFormState({ ...formState, personGender: event.target.value })} style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}>
                  <option value="Unspecified">Prefer not to say</option>
                  <option value="Female">Female</option>
                  <option value="Male">Male</option>
                  <option value="Non-binary">Non-binary</option>
                </select>
              </label>
            </>
          )}

          {resourceType === 'circle' && (
            <>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Circle name</span>
                <input
                  required
                  value={formState.circleName}
                  onChange={(event) => setFormState({ ...formState, circleName: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Description</span>
                <textarea
                  required
                  value={formState.description}
                  onChange={(event) => setFormState({ ...formState, description: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee', minHeight: '90px' }}
                />
              </label>
            </>
          )}

          {resourceType === 'project' && (
            <>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Project name</span>
                <input
                  required
                  value={formState.projectName}
                  onChange={(event) => setFormState({ ...formState, projectName: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Status</span>
                <select
                  value={formState.projectStatus}
                  onChange={(event) => setFormState({ ...formState, projectStatus: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                >
                  <option value="Active">Active</option>
                  <option value="Planning">Planning</option>
                  <option value="Completed">Completed</option>
                </select>
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Description</span>
                <textarea
                  required
                  value={formState.description}
                  onChange={(event) => setFormState({ ...formState, description: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee', minHeight: '90px' }}
                />
              </label>
            </>
          )}

          {resourceType === 'task' && (
            <>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Task title</span>
                <input
                  required
                  value={formState.taskTitle}
                  onChange={(event) => setFormState({ ...formState, taskTitle: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Task status</span>
                <select
                  value={formState.taskStatus}
                  onChange={(event) => setFormState({ ...formState, taskStatus: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                >
                  <option value="Todo">Todo</option>
                  <option value="In Progress">In Progress</option>
                  <option value="Done">Done</option>
                </select>
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Project (optional)</span>
                <select
                  value={formState.taskProjectId}
                  onChange={(event) => setFormState({ ...formState, taskProjectId: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                >
                  <option value="">No project</option>
                  {projects.map((project) => (
                    <option key={project.id || project.name} value={String(project.id)}>
                      {project.name}
                    </option>
                  ))}
                </select>
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Milestone (optional)</span>
                <select
                  value={formState.taskMilestoneId}
                  onChange={(event) => setFormState({ ...formState, taskMilestoneId: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                >
                  <option value="">No milestone</option>
                  {milestones.map((milestone) => (
                    <option key={milestone.id || milestone.name} value={String(milestone.id)}>
                      {milestone.name}
                    </option>
                  ))}
                </select>
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Task details</span>
                <textarea
                  required
                  value={formState.taskDetails}
                  onChange={(event) => setFormState({ ...formState, taskDetails: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee', minHeight: '90px' }}
                />
              </label>
            </>
          )}

          {resourceType === 'milestone' && (
            <>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Milestone name</span>
                <input
                  required
                  value={formState.milestoneName}
                  onChange={(event) => setFormState({ ...formState, milestoneName: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Milestone status</span>
                <select
                  value={formState.milestoneStatus}
                  onChange={(event) => setFormState({ ...formState, milestoneStatus: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                >
                  <option value="Planned">Planned</option>
                  <option value="In Progress">In Progress</option>
                  <option value="Blocked">Blocked</option>
                  <option value="Completed">Completed</option>
                </select>
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Project (optional)</span>
                <select
                  value={formState.milestoneProjectId}
                  onChange={(event) => setFormState({ ...formState, milestoneProjectId: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                >
                  <option value="">No project</option>
                  {projects.map((project) => (
                    <option key={project.id || project.name} value={String(project.id)}>
                      {project.name}
                    </option>
                  ))}
                </select>
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Milestone description</span>
                <textarea
                  required
                  value={formState.milestoneDescription}
                  onChange={(event) => setFormState({ ...formState, milestoneDescription: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee', minHeight: '90px' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Due date (optional)</span>
                <input
                  type="date"
                  value={formState.milestoneDueDate}
                  onChange={(event) => setFormState({ ...formState, milestoneDueDate: event.target.value })}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
                />
              </label>
              <label style={{ display: 'grid', gap: '0.35rem' }}>
                <span>Blocked reason {formState.milestoneStatus === 'Blocked' ? '(required)' : '(optional)'}</span>
                <textarea
                  value={formState.milestoneBlockedReason}
                  onChange={(event) => setFormState({ ...formState, milestoneBlockedReason: event.target.value })}
                  disabled={formState.milestoneStatus !== 'Blocked'}
                  placeholder={formState.milestoneStatus === 'Blocked' ? 'Describe what is blocking this milestone' : 'Set status to Blocked to add a reason'}
                  style={{ padding: '0.7rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee', minHeight: '80px' }}
                />
              </label>
            </>
          )}

          <button className="btn btn-primary" type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Submitting...' : 'Create record'}
          </button>
          <p style={{ color: '#2563eb', margin: 0 }}>{status}</p>
        </form>
      </section>

      <section className="grid" style={{ marginTop: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
        <div className="card">
          <h3>Users</h3>
          <ul>{users.map((user) => <li key={user.id || user.username}>{user.username || user.phoneNumber} {sessionUser?.role === 'ADMIN' && <button type="button" className="btn btn-secondary" style={{ padding: '0.2rem 0.45rem', marginLeft: '0.4rem' }} onClick={() => handleAdminEdit('user', user)}>Edit</button>}</li>)}</ul>
        </div>
        <div className="card">
          <h3>People</h3>
          <div>{people.map((person) => {
            const gender = String(person.gender || 'Unspecified').toLowerCase().replace(/\s+/g, '-');
            return <div className={`person-chip gender-${gender}`} key={person.id || person.email}><span className="person-avatar">{String(person.fullName || '?').charAt(0)}</span><span><strong>{person.fullName}</strong><small style={{ display: 'block' }}>{person.gender || 'Unspecified'}</small></span>{sessionUser?.role === 'ADMIN' && <button type="button" className="btn btn-secondary" style={{ padding: '0.2rem 0.45rem', marginLeft: 'auto' }} onClick={() => handleAdminEdit('person', person)}>Edit</button>}</div>;
          })}</div>
        </div>
        <div className="card">
          <h3>Circles</h3>
          <ul>{circles.map((circle) => <li key={circle.id || circle.name}>{circle.name} {sessionUser?.role === 'ADMIN' && <button type="button" className="btn btn-secondary" style={{ padding: '0.2rem 0.45rem', marginLeft: '0.4rem' }} onClick={() => handleAdminEdit('circle', circle)}>Edit</button>}</li>)}</ul>
        </div>
        <div className="card">
          <h3>Supported relationship types</h3>
          <p style={{ color: '#64748b' }}>Family types are used by the tree. Friend, Colleague, and Other remain network-only connections.</p>
          <div>{supportedRelationshipTypes.map((type) => <div key={type}><div className="relationship-line" /><span>{type}</span></div>)}</div>
        </div>
        <div className="card">
          <h3>Permissions</h3>
          <ul>{permissions.map((permission) => <li key={permission.id || permission.name}>{permission.name} {sessionUser?.role === 'ADMIN' && <button type="button" className="btn btn-secondary" style={{ padding: '0.2rem 0.45rem', marginLeft: '0.4rem' }} onClick={() => handleAdminEdit('permission', permission)}>Edit</button>}</li>)}</ul>
        </div>
        <div className="card">
          <h3>Projects</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.35rem', marginBottom: '0.5rem' }}>
            {sessionUser?.role === 'ADMIN' && projects.map((project) => <button key={`edit-project-${project.id}`} type="button" className="btn btn-secondary" style={{ padding: '0.2rem 0.45rem' }} onClick={() => handleAdminEdit('project', project)}>Edit {project.name}</button>)}
          </div>
          <ul>{projects.map((project) => <li key={project.id || project.name}>{project.name} • {project.status}</li>)}</ul>
        </div>
        <div className="card">
          <h3>Tasks</h3>
          {sessionUser?.role === 'ADMIN' && <button type="button" className="btn btn-secondary" style={{ padding: '0.2rem 0.45rem' }} onClick={() => handleAdminCreate('task group')}>Add task group</button>}
          <p style={{ color: '#64748b' }}>Groups: {taskGroups.length ? taskGroups.map((group) => group.name).join(', ') : 'None'}</p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.35rem', marginBottom: '0.5rem' }}>
            {sessionUser?.role === 'ADMIN' && tasks.map((task) => <button key={`edit-task-${task.id}`} type="button" className="btn btn-secondary" style={{ padding: '0.2rem 0.45rem' }} onClick={() => handleAdminEdit('task', task)}>Edit {task.title}</button>)}
          </div>
          <ul>{tasks.map((task) => <li key={task.id || task.title}>{task.title} • {task.status}{task.milestoneId ? ` • Milestone ${task.milestoneId}` : ''}</li>)}</ul>
        </div>
        <div className="card">
          <h3>Milestones</h3>
          <ul>{milestones.map((milestone) => <li key={milestone.id || milestone.name}>{milestone.name} • {milestone.status}</li>)}</ul>
        </div>
      </section>

      <section className="card" style={{ marginTop: '1rem' }}>
        <h3>Milestone Roadmap</h3>
        <p style={{ color: '#64748b', marginTop: 0 }}>Timeline view of milestones with linked tasks.</p>
        <div style={{ display: 'grid', gap: '0.6rem', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', marginTop: '0.75rem' }}>
          <label style={{ display: 'grid', gap: '0.35rem' }}>
            <span style={{ fontSize: '0.88rem', color: '#475569' }}>Filter by project</span>
            <select
              value={roadmapProjectFilter}
              onChange={(event) => setRoadmapProjectFilter(event.target.value)}
              style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
            >
              <option value="all">All projects</option>
              {projects.map((project) => (
                <option key={project.id || project.name} value={String(project.id)}>
                  {project.name}
                </option>
              ))}
            </select>
          </label>
          <label style={{ display: 'grid', gap: '0.35rem' }}>
            <span style={{ fontSize: '0.88rem', color: '#475569' }}>Filter by status</span>
            <select
              value={roadmapStatusFilter}
              onChange={(event) => setRoadmapStatusFilter(event.target.value)}
              style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
            >
              <option value="all">All status</option>
              <option value="Planned">Planned</option>
              <option value="In Progress">In Progress</option>
              <option value="Blocked">Blocked</option>
              <option value="Completed">Completed</option>
            </select>
          </label>
          <label style={{ display: 'grid', gap: '0.35rem' }}>
            <span style={{ fontSize: '0.88rem', color: '#475569' }}>Sort milestones</span>
            <select
              value={roadmapSort}
              onChange={(event) => setRoadmapSort(event.target.value)}
              style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
            >
              <option value="status-priority">Status priority</option>
              <option value="most-blocked-first">Most blocked first</option>
              <option value="least-progress-first">Least progress first</option>
            </select>
          </label>
          <label style={{ display: 'grid', gap: '0.35rem' }}>
            <span style={{ fontSize: '0.88rem', color: '#475569' }}>Search milestones</span>
            <input
              value={roadmapQuery}
              onChange={(event) => setRoadmapQuery(event.target.value)}
              placeholder="Search name or description"
              style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
            />
          </label>
        </div>
        <div style={{ marginTop: '0.8rem', padding: '0.7rem 0.8rem', border: '1px solid #dbe3ee', borderRadius: '0.7rem', background: '#fff' }}>
          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: '0.55rem' }}>
            <button
              type="button"
              className="btn btn-secondary"
              style={{ padding: '0.45rem 0.75rem' }}
              onClick={toggleSelectAllVisible}
              disabled={visibleMilestoneIds.length === 0 || bulkStatusPending}
            >
              {allVisibleSelected ? 'Clear Visible' : 'Select Visible'}
            </button>
            <button
              type="button"
              className="btn btn-secondary"
              style={{ padding: '0.45rem 0.75rem', background: '#dcfce7', color: '#166534' }}
              onClick={() => handleBulkMilestoneStatus('Completed')}
              disabled={selectedMilestoneIds.length === 0 || bulkStatusPending}
            >
              Mark Selected Completed
            </button>
            <button
              type="button"
              className="btn btn-secondary"
              style={{ padding: '0.45rem 0.75rem', background: '#e0f2fe', color: '#0c4a6e' }}
              onClick={() => handleBulkMilestoneStatus('In Progress')}
              disabled={selectedMilestoneIds.length === 0 || bulkStatusPending}
            >
              Mark Selected In Progress
            </button>
            <button
              type="button"
              className="btn btn-secondary"
              style={{ padding: '0.45rem 0.75rem', background: '#fef3c7', color: '#92400e' }}
              onClick={() => handleBulkMilestoneStatus('Blocked')}
              disabled={selectedMilestoneIds.length === 0 || bulkStatusPending}
            >
              Mark Selected Blocked
            </button>
            <span style={{ fontSize: '0.85rem', color: '#64748b', fontWeight: 700 }}>
              {selectedMilestoneIds.length} selected
            </span>
          </div>
        </div>
        <div style={{ display: 'grid', gap: '0.85rem', marginTop: '0.8rem' }}>
          {milestones.length === 0 && <p style={{ margin: 0, color: '#94a3b8' }}>No milestones yet.</p>}
          {milestones.length > 0 && sortedRoadmapMilestones.length === 0 && (
            <p style={{ margin: 0, color: '#94a3b8' }}>No milestones match your current filters.</p>
          )}
          {sortedRoadmapMilestones.map((milestone) => {
            const linkedTasks = tasks.filter((task) => task.milestoneId === milestone.id);
            const isEditing = editingMilestoneId === milestone.id;
            const progress = getMilestoneProgress(milestone.id);
            const isSelected = selectedMilestoneIds.includes(milestone.id);
            const isOverdue = isMilestoneOverdue(milestone);
            return (
              <div key={milestone.id || milestone.name} style={{ border: '1px solid #dbe3ee', borderRadius: '0.85rem', padding: '0.9rem 1rem', background: '#f8fbff' }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '0.8rem' }}>
                  <label style={{ display: 'inline-flex', alignItems: 'center', gap: '0.4rem', color: '#334155', fontSize: '0.84rem', fontWeight: 700 }}>
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onChange={() => toggleMilestoneSelection(milestone.id)}
                      disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                    />
                    Select
                  </label>
                  {!isEditing ? (
                    <>
                      <div>
                        <p style={{ margin: 0, fontWeight: 700 }}>{milestone.name}</p>
                        <p style={{ margin: '0.25rem 0 0', color: '#64748b', fontSize: '0.92rem' }}>{milestone.description}</p>
                        <p style={{ margin: '0.35rem 0 0', color: isOverdue ? '#b91c1c' : '#475569', fontSize: '0.82rem', fontWeight: 700 }}>
                          {milestone.dueDate ? `Due ${milestone.dueDate}${isOverdue ? ' (overdue)' : ''}` : 'No due date'}
                        </p>
                        {milestone.status === 'Blocked' && milestone.blockedReason && (
                          <p style={{ margin: '0.35rem 0 0', color: '#92400e', fontSize: '0.82rem', fontWeight: 700 }}>
                            Blocked: {milestone.blockedReason}
                          </p>
                        )}
                      </div>
                      <span style={{ fontSize: '0.8rem', fontWeight: 700, padding: '0.3rem 0.6rem', borderRadius: '999px', background: '#dbeafe', color: '#1e3a8a' }}>
                        {milestone.status}
                      </span>
                    </>
                  ) : (
                    <div style={{ width: '100%', display: 'grid', gap: '0.55rem' }}>
                      <input
                        value={milestoneEditState.name}
                        onChange={(event) => setMilestoneEditState({ ...milestoneEditState, name: event.target.value })}
                        style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
                      />
                      <textarea
                        value={milestoneEditState.description}
                        onChange={(event) => setMilestoneEditState({ ...milestoneEditState, description: event.target.value })}
                        style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1', minHeight: '80px' }}
                      />
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '0.55rem' }}>
                        <select
                          value={milestoneEditState.status}
                          onChange={(event) => setMilestoneEditState({ ...milestoneEditState, status: event.target.value })}
                          style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
                        >
                          <option value="Planned">Planned</option>
                          <option value="In Progress">In Progress</option>
                          <option value="Blocked">Blocked</option>
                          <option value="Completed">Completed</option>
                        </select>
                        <select
                          value={milestoneEditState.projectId}
                          onChange={(event) => setMilestoneEditState({ ...milestoneEditState, projectId: event.target.value })}
                          style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
                        >
                          <option value="">No project</option>
                          {projects.map((project) => (
                            <option key={project.id || project.name} value={String(project.id)}>
                              {project.name}
                            </option>
                          ))}
                        </select>
                        <input
                          type="date"
                          value={milestoneEditState.dueDate}
                          onChange={(event) => setMilestoneEditState({ ...milestoneEditState, dueDate: event.target.value })}
                          style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1' }}
                        />
                      </div>
                      <textarea
                        value={milestoneEditState.blockedReason}
                        onChange={(event) => setMilestoneEditState({ ...milestoneEditState, blockedReason: event.target.value })}
                        disabled={milestoneEditState.status !== 'Blocked'}
                        placeholder={milestoneEditState.status === 'Blocked' ? 'Describe what is blocking this milestone' : 'Set status to Blocked to add a reason'}
                        style={{ padding: '0.55rem 0.65rem', borderRadius: '0.6rem', border: '1px solid #cbd5e1', minHeight: '74px' }}
                      />
                    </div>
                  )}
                </div>
                <div style={{ marginTop: '0.55rem', color: '#475569', fontSize: '0.9rem' }}>
                  {linkedTasks.length === 0 ? 'No linked tasks yet.' : `${linkedTasks.length} linked task(s): ${linkedTasks.map((task) => task.title).join(', ')}`}
                </div>
                <div style={{ marginTop: '0.5rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.82rem', color: '#64748b', marginBottom: '0.25rem' }}>
                    <span>Task progress</span>
                    <span>{progress.completedTasks}/{progress.totalTasks} done ({progress.percent}%)</span>
                  </div>
                  <div className="milestone-progress-track">
                    <div className="milestone-progress-fill" style={{ width: `${progress.percent}%` }} />
                  </div>
                </div>
                <div style={{ marginTop: '0.7rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                  {!isEditing ? (
                    <>
                      <button
                        type="button"
                        className="btn btn-secondary"
                        style={{ padding: '0.5rem 0.8rem' }}
                        onClick={() => startMilestoneEdit(milestone)}
                        disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                      >
                        Edit
                      </button>
                      {milestone.status !== 'Completed' && (
                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ padding: '0.5rem 0.8rem', background: '#dcfce7', color: '#166534' }}
                          onClick={() => handleMilestoneQuickStatus(milestone.id, 'Completed')}
                          disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                        >
                          Mark Completed
                        </button>
                      )}
                      {milestone.status !== 'In Progress' && (
                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ padding: '0.5rem 0.8rem', background: '#e0f2fe', color: '#0c4a6e' }}
                          onClick={() => handleMilestoneQuickStatus(milestone.id, 'In Progress')}
                          disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                        >
                          Mark In Progress
                        </button>
                      )}
                      {milestone.status !== 'Blocked' && (
                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ padding: '0.5rem 0.8rem', background: '#fef3c7', color: '#92400e' }}
                          onClick={() => handleMilestoneQuickStatus(milestone.id, 'Blocked')}
                          disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                        >
                          Mark Blocked
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn"
                        style={{ padding: '0.5rem 0.8rem', background: '#fee2e2', color: '#991b1b' }}
                        onClick={() => handleMilestoneDelete(milestone.id)}
                        disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                      >
                        Delete
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        type="button"
                        className="btn btn-primary"
                        style={{ padding: '0.5rem 0.8rem' }}
                        onClick={() => handleMilestoneSave(milestone.id)}
                        disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                      >
                        Save
                      </button>
                      <button
                        type="button"
                        className="btn btn-secondary"
                        style={{ padding: '0.5rem 0.8rem' }}
                        onClick={cancelMilestoneEdit}
                        disabled={bulkStatusPending || milestoneActionPendingId === milestone.id}
                      >
                        Cancel
                      </button>
                    </>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </section>
    </main>
  );
}
