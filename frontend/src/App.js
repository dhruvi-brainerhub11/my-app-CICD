import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';
import UserForm from './components/UserForm';
import UserList from './components/UserList';

function App() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);

  const API_URL = process.env.REACT_APP_API_URL || 'my-app-alb-1553941597.ap-south-1.elb.amazonaws.com/api/health';

  // Fetch all users
  const fetchUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(`${API_URL}/api/users`);
      setUsers(response.data.data);
    } catch (err) {
      console.error('Error fetching users:', err);
      const msg = err.response?.data?.error || err.message || 'Failed to fetch users';
      setError(`Failed to fetch users: ${msg}`);
      setUsers([]);
    } finally {
      setLoading(false);
    }
  };

  // Initial fetch
  useEffect(() => {
    fetchUsers();
  }, []);

  // Handle form submission
  const handleAddUser = async (formData) => {
    try {
      const response = await axios.post(`${API_URL}/api/users`, formData);
      setSuccess('User added successfully!');
      setError(null);
      
      // Clear success message after 3 seconds
      setTimeout(() => setSuccess(null), 3000);
      
      // Refresh user list
      fetchUsers();
    } catch (err) {
      if (err.response?.data?.error) {
        setError(err.response.data.error);
      } else {
        setError('Failed to add user. Please try again.');
      }
    }
  };

  // Handle delete user
  const handleDeleteUser = async (id) => {
    if (!window.confirm('Are you sure you want to delete this user?')) {
      return;
    }

    try {
      await axios.delete(`${API_URL}/api/users/${id}`);
      setSuccess('User deleted successfully!');
      setError(null);
      
      // Clear success message after 3 seconds
      setTimeout(() => setSuccess(null), 3000);
      
      // Refresh user list
      fetchUsers();
    } catch (err) {
      setError('Failed to delete user. Please try again.');
      setSuccess(null);
      console.error('Error deleting user:', err);
    }
  };

  return (
    <div className="App">
      <div className="container">
        <header className="header">
          <h1>Dhruvi's User Input Application</h1>
          <p>Manage your user information efficiently</p>
        </header>

        {success && <div className="alert alert-success">{success}</div>}
        {error && <div className="alert alert-error">{error}</div>}

        <div className="content">
          <div className="form-section">
            <h2>Add New User</h2>
            <UserForm onSubmit={handleAddUser} />
          </div>

          <div className="list-section">
            <h2>Users List ({users.length})</h2>
            {loading ? (
              <div className="loading">Loading users...</div>
            ) : users.length === 0 ? (
              <div className="empty-state">No users found. Add one to get started!</div>
            ) : (
              <UserList users={users} onDelete={handleDeleteUser} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
